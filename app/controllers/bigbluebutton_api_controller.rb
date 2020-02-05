# frozen_string_literal: true

class BigBlueButtonApiController < ApplicationController
  include ApiHelper

  def index
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.version('2.0')
      end
    end

    render(xml: builder)
  end

  def get_meeting_info
    raise MeetingNotFoundError if params[:meetingID].blank?

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
      response = get_req(uri)
    rescue BBBError => e
      if e.message_key == 'notFound'
        # If the meeting is not found, delete the meeting from the load balancer database
        logger.debug("Meeting #{params[:meetingID]} not found on server; deleting from database.")
        meeting.destroy!
      end
      # Reraise the error
      raise e
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
      response = get_req(uri)
    rescue BBBError => e
      if e.message_key == 'notFound'
        # If the meeting is not found, delete the meeting from the load balancer database
        logger.debug("Meeting #{params[:meetingID]} not found on server; deleting from database.")
        meeting.destroy!
      end
      # Reraise the error
      raise e
    rescue StandardError => e
      logger.warn("Error #{e} accessing meeting #{params[:meetingID]} on server.")
      raise InternalError, 'Unable to access meeting on server.'
    end

    # Render response from the server
    render(xml: response)
  end

  def get_meetings
    # Get all available servers
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
      uri = encode_bbb_uri('getMeetings', server.url, server.secret)

      begin
        # Send a GET request to the server
        response = get_req(uri)

        # Skip over if no meetings on this server
        server_meetings = response.at_xpath('/response/meetings').children
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
end
