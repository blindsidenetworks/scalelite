# frozen_string_literal: true

class ApplicationController < ActionController::API
  include BBBErrors

  rescue_from BBBError do |e|
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('FAILED')
        xml.messageKey(e.message_key)
        xml.message(e.message)
      end
    end

    render(xml: builder)
  end
end
