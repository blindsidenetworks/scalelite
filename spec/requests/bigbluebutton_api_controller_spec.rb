# frozen_string_literal: true

require 'rails_helper'
require 'requests/shared_examples'

RSpec.describe BigBlueButtonApiController, type: :request do
  include BBBErrors
  include ApiHelper

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

  describe '#getMeetingInfo' do
    let(:server) { Server.create!(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1') }
    let!(:meeting) { Meeting.create!(id: 'test-meeting-1', server: server) }
    let(:url) {
 'https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=7901d9cf0f7e63a7e5eacabfd75fabfb223259d6c045ac5b4d86fb774c371945'
    }

    before do
      stub_request(:get, url)
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

  # get_meetings
  describe '#get_meetings' do
    let(:server1) { create(:server) }
    let(:server2) { create(:server) }
    let(:server3) { create(:server) }
    let(:server4) { create(:server) }

    context 'GET request' do
      it 'responds with the correct meetings' do
        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(@response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]")).to be_present
      end

      it 'responds with the appropriate error on timeout' do
        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_timeout
        stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(@response.body)
        expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
        expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to access server."))
      end

      it 'responds with noMeetings if there are no meetings on any server' do
        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(@response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq("noMeetings"))
        expect(response_xml.at_xpath("/response/message").text).to(eq("no meetings were found on this server"))
        expect(response_xml.at_xpath("/response/meetings").text).to(eq(""))
      end

      it 'only makes a request to online and enabled servers' do
        server3.online = false
        server3.enabled = false
        server3.save

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(@response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]")).not_to be_present
      end

      it 'only makes a request to online servers in state cordoned/enabled' do
        server1.state = "cordoned"
        server1.save
        server2.state = "enabled"
        server2.save
        server3.online = "false"
        server3.save
        server4.state = "disabled"
        server4.save

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
        # stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret))
        #   .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3<meeting></meetings></response>")
        # stub_request(:get, encode_bbb_uri("getMeetings", server4.url, server4.secret))
        #   .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-4<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(@response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]")).not_to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-4\"]")).not_to be_present
      end
    end

    context 'POST request' do
      it 'responds with the correct meetings' do
        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")

        post bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(response_xml.xpath('//meeting[text()="test-meeting-1"]')).to be_present
        expect(response_xml.xpath('//meeting[text()="test-meeting-2"]')).to be_present
      end
    end
  end
end
