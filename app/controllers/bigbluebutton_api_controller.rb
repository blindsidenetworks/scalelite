# frozen_string_literal: true

class BigBlueButtonApiController < ApplicationController
  def index
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.response do
        xml.returncode('SUCCESS')
        xml.version('2.0')
      end
    end

    render(xml: builder)
  end
end
