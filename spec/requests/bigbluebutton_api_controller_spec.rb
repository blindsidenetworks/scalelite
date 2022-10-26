# frozen_string_literal: true

require 'rails_helper'
require 'requests/shared_examples'

RSpec.describe BigBlueButtonApiController, type: :request do
  include BBBErrors

  before do
    allow_any_instance_of(BigBlueButtonApiController).to receive(:verify_checksum).and_return(nil)
  end

  describe '#index' do
    context 'GET request' do
      before { get bigbluebutton_api_url }

      include_examples 'returns success XML response'

      it 'does not return build' do
        response_xml = Nokogiri::XML(@response.body)
        expect(response_xml.at_xpath('/response/build')).to_not be_present
      end
    end

    context 'POST request' do
      before { post bigbluebutton_api_url }

      include_examples 'returns success XML response'

      it 'does not return build' do
        response_xml = Nokogiri::XML(@response.body)
        expect(response_xml.at_xpath('/response/build')).to_not be_present
      end
    end

    context 'with env variable is set' do
      before do
        Rails.configuration.x.build_number = 'alpha-1'
        get bigbluebutton_api_url
      end

      include_examples 'returns success XML response'

      it 'includes build in response' do
        response_xml = Nokogiri::XML(@response.body)
        expect(response_xml.at_xpath('/response/build')).to be_present
      end
    end
  end

  xdescribe '#getMeetingInfo' do
    let(:server) { Server.create!(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1') }
    let!(:meeting) { Meeting.create!(id: 'test-meeting-1', server: server) }
    let(:url) {
 'https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=7901d9cf0f7e63a7e5eacabfd75fabfb223259d6c045ac5b4d86fb774c371945'
    }

    before do
      WebMock.stub_request(:get, url)
             .to_return(body: '<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>')

      post bigbluebutton_api_get_meeting_info_url, params: { meetingID: 'test-meeting-1' }
    end

    context 'with POST request' do
      it 'responds with the correct meeting info' do
        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/returncode').text).to eq 'SUCCESS'
      end
    end
    context 'with POST request with checksum value' do
      context 'computed with SHA1' do
      end

      context 'computed with SHA256' do
      end
    end

    context 'with timeout' do
      it 'responds with appropriate error'
    end

    context 'with meeting ID not provided' do
      it 'responds with MissingMeetingIDError'
    end

    context 'with meeting ID not in database' do
      it 'resonds with MeetingNotFoundError'
    end
  end

  describe '#isMeetingRunning' do
    context 'with GET request' do
      it 'responds with correct meeting status'

      # line 262
      it 'responds with the correct meetings'
    end

    context 'with POST request' do
      it 'responds with correct meeting status'

      # line 286
      it 'responds with correct meetings'
    end

    context 'on timeout' do
      it 'responds with appropriate error'
    end

    context 'with meeting ID not passed' do
      it 'responds with MissingMeetingIDError'
    end

    context 'with meeting not found in database' do
      it 'responds with false'
    end
  end
end
