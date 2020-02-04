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
      # Respond with MeetingNotFoundError if the meeting could not be found
      logger.info("The requested meeting #{params[:meetingID]} does not exist")
      raise MeetingNotFoundError
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
end
