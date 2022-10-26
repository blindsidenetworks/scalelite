require 'rails_helper'
require 'requests/shared_examples'

RSpec.describe ErrorsController, type: :request do
  #TODO either test description or behavior is not correct
  describe 'with request url is root' do
    before do
      get root_url
    end

    xit 'returns unsupportedRequestError' do
      expect(response.status).to eq 200
    end
  end

  describe 'with invalid url' do
    before do
      get '/unsupportedRequest'
    end

    include_examples 'returns unsupportedRequestError'
  end

  describe 'unknown BBB api commands' do
    before do
      get '/bigbluebutton/api/unsupportedRequest'
    end

    include_examples 'returns unsupportedRequestError'
  end
end

