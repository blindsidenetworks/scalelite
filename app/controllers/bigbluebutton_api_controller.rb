# frozen_string_literal: true

class BigBlueButtonApiController < ApplicationController
  include ApiHelper

  skip_before_action :verify_authenticity_token

  # Check content types on endpoints that accept POST requests. For most endpoints, form data is permitted.
  before_action :verify_content_type, except: [:create, :insert_document, :join, :publish_recordings, :delete_recordings, :analytics_callback]
  # create allows either form data or XML
  before_action :verify_create_content_type, only: [:create]
  # insertDocument only allows XML
  before_action :verify_insert_document_content_type, only: [:insert_document]

  before_action :verify_checksum, except: [:index, :get_recordings_disabled, :recordings_disabled, :get_meetings_disabled,
                                           :analytics_callback,]

  before_action :set_tenant, except: [:index, :get_recordings_disabled, :recordings_disabled, :get_meetings_disabled],
                if: -> { Rails.configuration.x.multitenancy_enabled }

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
      meeting = Meeting.find(params[:meetingID], @tenant&.id)
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
      meeting = Meeting.find(params[:meetingID], @tenant&.id)
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
      # only send getMeetings requests to servers that have state as enabled/cordoned
      next if server.offline? || server.disabled?

      uri = encode_bbb_uri('getMeetings', server.url, server.secret)

      begin
        # Send a GET request to the server
        response = get_post_req(uri)

        # filter to only show messages for current Tenant
        if @tenant.present?
          response.xpath('/response/meetings/meeting').each do |m|
            meeting_tenant_id = m.xpath('metadata/tenant-id').text
            m.remove if meeting_tenant_id != @tenant.id
          end
        else
          response.xpath('/response/meetings/meeting').each do |m|
            meeting_tenant_id = m.xpath('metadata/tenant-id').text
            m.remove if meeting_tenant_id.present?
          end
        end

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

    apply_config_server_tag(params)
    begin
      # Check if meeting is already running
      meeting = Meeting.find(params[:meetingID], @tenant&.id)
      server = meeting.server
      logger.debug("Found existing meeting #{params[:meetingID]} on BigBlueButton server #{server.id}.")
    rescue ApplicationRedisRecord::RecordNotFound
      begin
        # Find available server and create meeting on it
        server = Server.find_available(params[:'meta_server-tag'])

        # Create meeting in database
        logger.debug("Creating meeting #{params[:meetingID]} in database.")
        moderator_pwd = params[:moderatorPW].presence || SecureRandom.alphanumeric(8)
        meeting = Meeting.find_or_create_with_server!(
          params[:meetingID],
          server,
          moderator_pwd,
          params[:voiceBridge],
          @tenant&.id
        )

        # Update server if meeting (unexpectedly) already existed on a different server
        server = meeting.server

        logger.debug("Incrementing server #{server.id} load by 1")
        server.increment_load(1)
      rescue ApplicationRedisRecord::RecordNotFound => e
        raise InternalError, e.message
      end
    end

    params[:moderatorPW] = meeting.moderator_pw
    params[:voiceBridge] = meeting.voice_bridge
    params[:'meta_tenant-id'] = @tenant.id if @tenant.present?
    if server.tag.present?
      params[:'meta_server-tag'] = server.tag
    else
      params.delete(:'meta_server-tag')
    end

    duration = params[:duration].to_i

    # Set/Overite duration if MAX_MEETING_DURATION is set and it's greater than params[:duration] (if passed)
    if !Rails.configuration.x.max_meeting_duration.zero? &&
       (duration.zero? || duration > Rails.configuration.x.max_meeting_duration)
      logger.debug("Setting duration to #{Rails.configuration.x.max_meeting_duration}")
      params[:duration] = Rails.configuration.x.max_meeting_duration
    end

    if @tenant&.lrs_endpoint.present?
      lrs_payload = LrsPayloadService.new(tenant: @tenant, secret: server.secret).call
      params[:'meta_secret-lrs-payload'] = lrs_payload if lrs_payload.present?
    end

    have_preuploaded_slide = request.post? && request.content_mime_type == Mime[:xml]

    logger.debug("Creating meeting #{params[:meetingID]} on BigBlueButton server #{server.id}")
    params_hash = params

    # EventHandler will handle all the events associated with the create action
    params = EventHandler.new(params_hash, meeting.id, @tenant).handle
    # Get list of params that should not be modified by create API call
    excluded_params = Rails.configuration.x.create_exclude_params
    # Pass along all params except the built in rails ones and excluded_params
    uri = encode_bbb_uri('create', server.url, server.secret, pass_through_params(excluded_params))

    begin
      # Read the body if preuploaded slide XML is present
      body = have_preuploaded_slide ? request.raw_post : ''

      # Send a GET/POST request to the server
      response = get_post_req(uri, body, **bbb_req_timeout(server))
    rescue BBBError
      # Reraise the error to return error xml to caller
      raise
    rescue StandardError => e
      logger.warn("Error #{e} creating meeting #{params[:meetingID]} on server #{server.id}.")
      logger.debug { e.full_message }
      raise InternalError, 'Unable to create meeting on server.'
    end

    # Render response from the server
    render(xml: response)
  end

  def end
    params.require(:meetingID)

    begin
      meeting = Meeting.find(params[:meetingID], @tenant&.id)
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
      meeting = Meeting.find(params[:meetingID], @tenant&.id)
      server = meeting.server
      raise ServerUnavailableError if server.offline? || server.disabled?
    rescue ServerUnavailableError
      logger.error("The server #{server.id} for meeting #{meeting.id} is offline") if server.offline?
      logger.error("The server #{server.id} for meeting #{meeting.id} has been disabled") if server.disabled?
      raise ServerDisabledError
    rescue ApplicationRedisRecord::RecordNotFound
      # Respond with MeetingNotFoundError if the meeting could not be found
      logger.info("The requested meeting #{params[:meetingID]} does not exist")
      raise MeetingNotFoundError
    end
    logger.debug("Incrementing server #{server.id} load by 1")
    server.increment_load(1)

    # Get list of params that should not be modified by join API call
    excluded_params = Rails.configuration.x.join_exclude_params

    # Pass along all params except the built in rails ones and excluded_params
    uri = encode_bbb_uri('join', server.url, server.secret, pass_through_params(excluded_params))

    # Redirect the user to the join url
    logger.debug("Redirecting user to join url: #{uri}")
    redirect_to(uri.to_s, allow_other_host: true)
  end

  def insert_document
    params.require(:meetingID)

    begin
      meeting = Meeting.find(params[:meetingID], @tenant&.id)
    rescue ApplicationRedisRecord::RecordNotFound # Respond with MeetingNotFoundError if the meeting could not be found
      logger.info("The requested meeting #{params[:meetingID]} does not exist")
      raise MeetingNotFoundError
    end

    server = meeting.server
    begin
      # Send a POST request to the server
      response = get_post_req(
        encode_bbb_uri('insertDocument', server.url, server.secret, meetingID: params[:meetingID]),
        request.body.read,
        **bbb_req_timeout(server)
      )
    rescue BBBError
      # Reraise the error to return error xml to caller
      raise
    rescue StandardError => e
      logger.warn("Error #{e} inserting document into meeting #{params[:meetingID]} on server #{server.id}.")
      logger.debug { e.full_message }
      raise InternalError, 'Unable to insert document on server.'
    end

    # Render response from the server
    render(xml: response)
  end

  def get_recordings
    if Rails.configuration.x.get_recordings_api_filtered && (params[:recordID].blank? && params[:meetingID].blank?)
      raise BBBError.new('missingParameters', 'param meetingID or recordID must be included.')
    end

    query = Recording.includes(playback_formats: [:thumbnails], metadata: []).left_joins(:metadata).distinct

    query = query.where(metadata: { key: "tenant-id", value: @tenant.id }) if @tenant.present?

    query = if params[:state].present?
              states = params[:state].split(',')
              states.include?('any') ? query : query.where(state: states)
            else
              query.state_is_published_unpublished
            end
    meta_params = params.select { |key, _value| key.to_s.match(/^meta_/) }.permit!.to_h.to_a
    if meta_params.present?
      meta_query = '(metadata.key = ? and metadata.value in (?))'
      meta_values = [meta_params[0][0].remove('meta_'), meta_params[0][1].split(',')]
      meta_params[1..].each do |val|
        meta_query += ' or (metadata.key = ? and metadata.value in (?))'
        meta_values << val[0].remove('meta_')
        meta_values << val[1].split(',')
      end
      query = query.where(meta_query.to_s, *meta_values)
    end
    query = query.with_recording_id_prefixes(params[:recordID].split(',')) if params[:recordID].present?
    query = query.where(meeting_id: params[:meetingID].split(',')) if params[:meetingID].present?

    @recordings = query.order(starttime: :desc).all
    @url_prefix = "#{request.protocol}#{request.host_with_port}"

    render(:get_recordings)
  end

  def publish_recordings
    raise BBBError.new('missingParamRecordID', 'You must specify a recordID.') if params[:recordID].blank?
    raise BBBError.new('missingParamPublish', 'You must specify a publish value true or false.') if params[:publish].blank?

    publish = params[:publish].casecmp('true').zero?

    query_params = { record_id: params[:recordID].split(',') }
    query_params[:metadata] = { key: 'tenant-id', value: @tenant.id } if @tenant.present? # filter based on tenant

    query = Recording.includes(:metadata).where(query_params).load
    query = query.state_is_published_unpublished
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
        state = publish ? 'published' : 'unpublished'
        rec.update!(published: publish, publish_updated: true, state: state)
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
    record_ids = params[:recordID].split(',')

    query_params = { record_id: record_ids }
    query_params[:metadata] = { key: 'tenant-id', value: @tenant.id } if @tenant.present? # filter based on tenant

    if Recording.includes(:metadata).where(query_params).blank?
      @updated = false
      return render(:update_recordings)
    end

    add_metadata = {}
    remove_metadata = []
    params.each do |key, value|
      next unless key.start_with?('meta_')

      key = key[5..].downcase

      if value.blank?
        remove_metadata << key
      else
        add_metadata[key] = value
      end
    end

    logger.debug("Adding metadata: #{add_metadata}")
    logger.debug("Removing metadata: #{remove_metadata}")
    recording_updated = false
    Metadatum.transaction do
      Metadatum.upsert_by_record_id(record_ids, add_metadata)
      Metadatum.delete_by_record_id(record_ids, remove_metadata)
      recording_updated = Recording.find_by(record_id: record_ids.first).update!(protected: params[:protect]) if params[:protect].present?
    end

    @updated = !(add_metadata.empty? && remove_metadata.empty?) || recording_updated
    render(:update_recordings)
  end

  def delete_recordings
    raise BBBError.new('missingParamRecordID', 'You must specify a recordID.') if params[:recordID].blank?

    query_params = { record_id: params[:recordID].split(',') }
    query_params[:metadata] = { key: 'tenant-id', value: @tenant.id } if @tenant.present? # filter based on tenant

    query = Recording.includes(:metadata).where(query_params).load
    raise BBBError.new('notFound', 'We could not find recordings') if query.none?

    query.each do |rec|
      # Start transaction + lock record
      rec.with_lock do
        logger.debug("Deleting recording: #{rec.record_id}")
        # TODO: check the unpublished dir when it is implemented
        FileUtils.rm_r(Dir.glob(File.join(Rails.configuration.x.recording_publish_dir, '/*/', rec.record_id)))
        rec.mark_delete!
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

  def analytics_callback
    token = request.headers['HTTP_AUTHORIZATION'].gsub('Bearer ', '')
    raise 'Token Invalid' unless valid_token?(token)

    meeting_id = params['meeting_id']

    logger.info("Making analytics callback for #{meeting_id}")
    callback_data = CallbackData.find_by(meeting_id: meeting_id)
    analytics_callback_url = callback_data&.callback_attributes&.dig(:analytics_callback_url)
    return if analytics_callback_url.nil?

    uri = URI.parse(analytics_callback_url)
    post_req(uri, params, @tenant&.name)
  rescue StandardError => e
    logger.info('Rescued')
    logger.info(e.to_s)
  end

  private

  # Filter out unneeded params when passing through to join and create calls
  # Has to be to_unsafe_hash since to_h only accepts permitted attributes
  def pass_through_params(excluded_params)
    params.except(*(excluded_params + [:format, :controller, :action, :checksum]))
          .to_unsafe_hash
  end

  def set_tenant
    @tenant = fetch_tenant
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
