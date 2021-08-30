# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include BBBErrors

  rescue_from BBBError do |e|
    render(xml: build_error(e.message_key, e.message))
  end

  rescue_from ActionController::ParameterMissing do |e|
    # Raise specific Missing Meeting ID error if thats the missing param
    error = if e.param == :meetingID
              MissingMeetingIDError.new
            else
              InternalError.new(e.message)
            end

    render(xml: build_error(error.message_key, error.message))
  end

  private

  # Generic XML builder for errors
  def build_error(key, message)
    Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('FAILED')
        xml.messageKey(key)
        xml.message(message)
      end
    end
  end
end
