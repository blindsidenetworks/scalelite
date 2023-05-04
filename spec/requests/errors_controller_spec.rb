# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ErrorsController, type: :request do
  describe 'GET root_url' do
    it 'returns unsupportedRequestError if request url is root' do
      get root_url

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /unsupportedRequest' do
    it 'returns unsupportedRequestError if the url is invalid' do
      get '/unsupportedRequest'

      response_xml = Nokogiri::XML(response.body)

      expect(response_xml.at_xpath('/response/returncode').text).to eq('FAILED')
      expect(response_xml.at_xpath('/response/messageKey').text).to eq('unsupportedRequest')
      expect(response_xml.at_xpath('/response/message').text).to eq('This request is not supported.')

      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /bigbluebutton/api/unsupportedRequest' do
    it 'returns unsupportedRequestError for unknown BBB api commands' do
      get '/bigbluebutton/api/unsupportedRequest'

      response_xml = Nokogiri::XML(response.body)

      expect(response_xml.at_xpath('/response/returncode').text).to eq('FAILED')
      expect(response_xml.at_xpath('/response/messageKey').text).to eq('unsupportedRequest')
      expect(response_xml.at_xpath('/response/message').text).to eq('This request is not supported.')

      expect(response).to have_http_status(:success)
    end
  end
end
