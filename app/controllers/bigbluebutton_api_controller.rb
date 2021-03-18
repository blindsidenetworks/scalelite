# frozen_string_literal: true

class BigBlueButtonApiController < ApplicationController
  include ApiHelper

  before_action :verify_checksum, except: [:index, :get_recordings_disabled, :recordings_disabled, :get_meetings_disabled]

  def index
    # Return the scalelite build number if passed as an env variable
    build_number = Rails.configuration.x.build_number

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.version('2.0')
        xml.build(build_number) if build_number.present?
      end
    end

    render(xml: builder)
  end

  def get_meeting_info
    params.require(:meetingID)

    begin
      meeting = Meeting.find(params[:meetingID])
    rescue ApplicationRedisRecord::RecordNotFound
      # Respond with MeetingNotFoundError if the meeting could not be found
      logger.info("The requested meeting #{params[:meetingID]} does not exist")
      raise MeetingNotFoundError
    end

    server = meeting.server
    # Construct getMeetingInfo call with the right url + secret and checksum
    uri = encode_bbb_uri('getMeetingInfo',
                         server.url,
                         server.secret,
                         'meetingID' => params[:meetingID])

    begin
      # Send a GET request to the server
      response = get_post_req(uri, **bbb_req_timeout(server))
    rescue BBBError
      # Reraise the error
      raise
    rescue StandardError => e
      logger.warn("Error #{e} accessing meeting #{params[:meetingID]} on server.")
      raise InternalError, 'Unable to access meeting on server.'
    end

    # Render response from the server
    render(xml: response)
  end

  def is_meeting_running
    params.require(:meetingID)

    begin
      meeting = Meeting.find(params[:meetingID])
    rescue ApplicationRedisRecord::RecordNotFound
      # Respond with false if the meeting could not be found
      logger.info("The requested meeting #{params[:meetingID]} does not exist")
      return render(xml: not_running_response)
    end

    server = meeting.server

    # Construct getMeetingInfo call with the right url + secret and checksum
    uri = encode_bbb_uri('isMeetingRunning',
                         server.url,
                         server.secret,
                         'meetingID' => params[:meetingID])

    begin
      # Send a GET request to the server
      response = get_post_req(uri, **bbb_req_timeout(server))
    rescue BBBError
      # Reraise the error
      raise
    rescue StandardError => e
      logger.warn("Error #{e} accessing meeting #{params[:meetingID]} on server.")
      raise InternalError, 'Unable to access meeting on server.'
    end

    # Render response from the server
    render(xml: response)
  end

  def get_meetings
    # Get all servers
    servers = Server.all

    logger.warn('No servers are currently available') if servers.empty?

    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.meetings
      end
    end

    all_meetings = builder.doc
    meetings_node = all_meetings.at_xpath('/response/meetings')

    # Make individual getMeetings call for each server and append result to all_meetings
    servers.each do |server|
      next unless server.online # only send getMeetings requests to servers that are online

      uri = encode_bbb_uri('getMeetings', server.url, server.secret)

      begin
        # Send a GET request to the server
        response = get_post_req(uri)

        # Skip over if no meetings on this server
        server_meetings = response.xpath('/response/meetings/meeting')
        next if server_meetings.empty?

        # Add all meetings returned from the getMeetings call to the list
        meetings_node.add_child(server_meetings)
      rescue BBBError => e
        raise e
      rescue StandardError => e
        logger.warn("Error #{e} accessing server #{server.id}.")
        raise InternalError, 'Unable to access server.'
      end
    end

    # Render all meetings if there are any or a custom no meetings response if no meetings exist
    render(xml: meetings_node.children.empty? ? no_meetings_response : all_meetings)
  end

  def get_meetings_disabled
    logger.debug('The get meetings api has been disabled')
    render(xml: no_meetings_response)
  end

  def create
    params.require(:meetingID)

    begin
      server = Server.find_available
    rescue ApplicationRedisRecord::RecordNotFound
      raise InternalError, 'Could not find any available servers.'
    end

    # Create meeting in database
    logger.debug("Creating meeting #{params[:meetingID]} in database.")

    moderator_pwd = params[:moderatorPW].presence || SecureRandom.alphanumeric(8)
    params[:moderatorPW] = moderator_pwd
    meeting = Meeting.find_or_create_with_server(params[:meetingID], server, moderator_pwd)

    # Update with old server if meeting already existed in database
    server = meeting.server

    logger.debug("Incrementing server #{server.id} load by 1")
    server.increment_load(1)

    duration = params[:duration].to_i

    # Set/Overite duration if MAX_MEETING_DURATION is set and it's greater than params[:duration] (if passed)
    if !Rails.configuration.x.max_meeting_duration.zero? &&
       (duration.zero? || duration > Rails.configuration.x.max_meeting_duration)
      logger.debug("Setting duration to #{Rails.configuration.x.max_meeting_duration}")
      params[:duration] = Rails.configuration.x.max_meeting_duration
    end

    logger.debug("Creating meeting #{params[:meetingID]} on BigBlueButton server #{server.id}")
    # Pass along all params except the built in rails ones
    uri = encode_bbb_uri('create', server.url, server.secret, pass_through_params)

    begin
      # Read the body if POST
      body = request.post? ? request.body.read : ''

      # Send a GET/POST request to the server
      response = get_post_req(uri, body, **bbb_req_timeout(server))
    rescue BBBError
      # Reraise the error to return error xml to caller
      raise
    rescue StandardError => e
      logger.warn("Error #{e} creating meeting #{params[:meetingID]} on server #{server.id}.")
      raise InternalError, 'Unable to create meeting on server.'
    end

    # Render response from the server
    render(xml: response)
  end

  def end
    params.require(:meetingID)

    begin
      meeting = Meeting.find(params[:meetingID])
    rescue ApplicationRedisRecord::RecordNotFound
      # Respond with MeetingNotFoundError if the meeting could not be found
      logger.info("The requested meeting #{params[:meetingID]} does not exist")
      raise MeetingNotFoundError
    end

    server = meeting.server

    # Construct end call with the right params
    uri = encode_bbb_uri('end', server.url, server.secret,
                         meetingID: params[:meetingID], password: params[:password])

    begin
      # Remove the meeting from the database
      meeting.destroy!

      # Send a GET request to the server
      response = get_post_req(uri, **bbb_req_timeout(server))
    rescue BBBError => e
      if e.message_key == 'notFound'
        # If the meeting is not found, delete the meeting from the load balancer database
        logger.debug("Meeting #{params[:meetingID]} not found on server; deleting from database.")
        meeting.destroy!
      end
      # Reraise the error
      raise e
    rescue ApplicationRedisRecord::RecordNotDestroyed => e
      logger.warn("Error #{e} deleting meeting #{params[:meetingID]} from server #{server.id}")
    rescue StandardError => e
      logger.warn("Error #{e} accessing meeting #{params[:meetingID]} on server #{server.id}.")
      raise InternalError, 'Unable to access meeting on server.'
    end

    # Render response from the server
    render(xml: response)
  end

  def join
    params.require(:meetingID)

    begin
      meeting = Meeting.find(params[:meetingID])
    rescue ApplicationRedisRecord::RecordNotFound
      # Respond with MeetingNotFoundError if the meeting could not be found
      logger.info("The requested meeting #{params[:meetingID]} does not exist")
      raise MeetingNotFoundError
    end

    server = meeting.server

    # Pass along all params except the built in rails ones
    uri = encode_bbb_uri('join', server.url, server.secret, pass_through_params)

    # Redirect the user to the join url
    logger.debug("Redirecting user to join url: #{uri}")
    redirect_to(uri.to_s)
  end

  def get_recordings
    query = Recording.includes(playback_formats: [:thumbnails], metadata: [])
    query = query.with_recording_id_prefixes(params[:recordID].split(',')) if params[:recordID].present?
    query = query.where(meeting_id: params[:meetingID].split(',')) if params[:meetingID].present?

    @recordings = query.order(starttime: :desc).all
    @url_prefix = "#{request.protocol}#{request.host}"

    render(:get_recordings)
  end

  def publish_recordings
    raise BBBError.new('missingParamRecordID', 'You must specify a recordID.') if params[:recordID].blank?
    raise BBBError.new('missingParamPublish', 'You must specify a publish value true or false.') if params[:publish].blank?

    publish = params[:publish].casecmp('true').zero?

    query = Recording.where(record_id: params[:recordID].split(','), state: 'published').load
    raise BBBError.new('notFound', 'We could not find recordings') if query.none?

    query.where.not(published: publish).each do |rec|
      rec.with_lock do
        logger.debug("Setting published=#{publish} for recording: #{rec.record_id}")

        target_dir = publish ? Rails.configuration.x.recording_publish_dir : Rails.configuration.x.recording_unpublish_dir
        current_dir = publish ? Rails.configuration.x.recording_unpublish_dir : Rails.configuration.x.recording_publish_dir

        rec.playback_formats.each do |playback|
          recording_path = File.join(current_dir, playback.format, rec.record_id)

          in_current = Dir.glob(recording_path).present?
          in_target = Dir.glob(File.join(target_dir, playback.format, rec.record_id)).present?

          # Next playback if already in correct place
          next if !in_current && in_target

          # If no recording files exists in either directory, raise not found
          raise StandardError, 'Recording has no recording files' if !in_current && !in_target

          # If recording files are in both directories
          if in_current && in_target
            Rails.logger.info("Recording #{rec.record_id} files found in both directories. Removing #{recording_path}")
            FileUtils.rm_r(recording_path)
            next
          end

          # Recording files are in current_dir and not in target_dir
          format_dir = File.join(target_dir, playback.format)
          FileUtils.mkdir_p(format_dir)
          FileUtils.mv(recording_path, format_dir)
        end

        rec.update(published: publish)
      rescue StandardError => e
        logger.warn("Error #{e} setting published=#{publish} recording #{rec.record_id}")
        raise InternalError, 'Unable to publish/unpublish recording.'
      end
    end

    @published = publish
    render(:publish_recordings)
  end

  def update_recordings
    raise BBBError.new('missingParamRecordID', 'You must specify a recordID.') if params[:recordID].blank?

    add_metadata = {}
    remove_metadata = []
    params.each do |key, value|
      next unless key.start_with?('meta_')

      key = key[5..-1].downcase

      if value.blank?
        remove_metadata << key
      else
        add_metadata[key] = value
      end
    end

    logger.debug("Adding metadata: #{add_metadata}")
    logger.debug("Removing metadata: #{remove_metadata}")

    record_ids = params[:recordID].split(',')
    Metadatum.transaction do
      Metadatum.upsert_by_record_id(record_ids, add_metadata)
      Metadatum.delete_by_record_id(record_ids, remove_metadata)
    end

    @updated = !(add_metadata.empty? && remove_metadata.empty?)
    render(:update_recordings)
  end

  def delete_recordings
    raise BBBError.new('missingParamRecordID', 'You must specify a recordID.') if params[:recordID].blank?

    query = Recording.where(record_id: params[:recordID].split(',')).load
    raise BBBError.new('notFound', 'We could not find recordings') if query.none?

    query.each do |rec|
      # Start transaction + lock record
      rec.with_lock do
        logger.debug("Deleting recording: #{rec.record_id}")
        # TODO: check the unpublished dir when it is implemented
        FileUtils.rm_r(Dir.glob(File.join(Rails.configuration.x.recording_publish_dir, '/*/', rec.record_id)))
        rec.destroy!
      rescue StandardError => e
        logger.warn("Error #{e} deleting recording #{rec.record_id}")
        raise InternalError, 'Unable to delete recording.'
      end
    end

    render(:delete_recordings)
  end

  def get_recordings_disabled
    logger.debug('The recording feature have been disabled')
    @recordings = []
    render(:get_recordings)
  end

  def recordings_disabled
    logger.debug('The recording feature have been disabled')
    raise BBBError.new('notFound', 'We could not find recordings')
  end

  private

  # Filter out unneeded params when passing through to join and create calls
  # Has to be to_unsafe_hash since to_h only accepts permitted attributes
  def pass_through_params
    params.except(:format, :controller, :action, :checksum).to_unsafe_hash
  end

  # Success response if there are no meetings on any servers
  def no_meetings_response
    Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.messageKey('noMeetings')
        xml.message('no meetings were found on this server')
        xml.meetings
      end
    end
  end

  # Not running response if meeting doesn't exist in database
  def not_running_response
    Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.running('false')
      end
    end
  end
end
