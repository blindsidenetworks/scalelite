# frozen_string_literal: true

require 'rails_helper'
require 'redis_helper'
require 'test_helper'
require 'requests/shared_examples'

RSpec.describe BigBlueButtonApiController, type: :request do
  include BBBErrors
  include ApiHelper
  include TestHelper

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
    context 'GET request' do
      it 'responds with the correct meetings' do
        server1 = create(:server)
        server2 = create(:server)

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(@response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))

        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
      end

      it 'responds with the appropriate error on timeout' do
        server1 = create(:server)
        server2 = create(:server)

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_timeout

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
        server1 = create(:server)
        server2 = create(:server)
        server3 = create(:server, online: false)

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
        server1 = create(:server, state: "cordoned")
        server2 = create(:server, state: "enabled")
        server3 = create(:server, online: false)
        server4 = create(:server, state: "disabled")

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server4.url, server4.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-4<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(@response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]")).not_to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-4\"]")).not_to be_present
      end

      it 'returns no meetings if GET_MEETINGS_API_DISABLED flag is set to true for a get request' do
        mock_env("GET_MEETINGS_API_DISABLED" => "TRUE") do
          reload_routes!
          get bigbluebutton_api_get_meetings_url
        end

        response_xml = Nokogiri::XML(response.body)
        expect(response).to have_http_status(:success)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(response_xml.at_xpath('/response/messageKey').text).to eq('noMeetings')
        expect(response_xml.at_xpath('/response/message').text).to eq('no meetings were found on this server')
        expect(response_xml.at_xpath('/response/meetings').text).to eq('')
      end
    end

    context 'POST requests' do
      it 'responds with the correct meetings' do
        server1 = create(:server)
        server2 = create(:server)

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

      it 'returns no meetings if GET_MEETINGS_API_DISABLED flag is set to true for a post request' do
        mock_env("GET_MEETINGS_API_DISABLED" => "TRUE") do
          reload_routes!
          post bigbluebutton_api_get_meetings_url
        end

        response_xml = Nokogiri::XML(response.body)
        expect(response).to have_http_status(:success)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(response_xml.at_xpath('/response/messageKey').text).to eq('noMeetings')
        expect(response_xml.at_xpath('/response/message').text).to eq('no meetings were found on this server')
        expect(response_xml.at_xpath('/response/meetings').text).to eq('')
      end
    end
  end

  describe '#get_meeting_info' do
    context 'GET request' do
      it 'responds with the correct meeting info for a get request' do
        server = create(:server)
        meeting = create(:meeting, server: server)

        stub_request(:get, encode_bbb_uri("getMeetingInfo", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>")

        get bigbluebutton_api_get_meeting_info_url, params: { meetingID: meeting.id }

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
        expect(response_xml.at_xpath("/response/meetingID").content).to(eq("test-meeting-1"))
      end

      it 'responds with appropriate error on timeout' do
        server = create(:server)
        meeting = create(:meeting, server: server)

        stub_request(:get, encode_bbb_uri("getMeetingInfo", server.url, server.secret, meetingID: meeting.id))
          .to_timeout

        get bigbluebutton_api_get_meeting_info_url, params: { meetingID: meeting.id }

        response_xml = Nokogiri.XML(response.body)

        expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
        expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to access meeting on server."))
      end

      it 'responds with MissingMeetingIDError if meeting ID is not passed' do
        get bigbluebutton_api_get_meeting_info_url

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MissingMeetingIDError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it 'responds with MeetingNotFoundError if meeting is not found in database' do
        get bigbluebutton_api_get_meeting_info_url, params: { meetingID: "test" }

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MeetingNotFoundError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end
    end

    context 'POST request' do
      it 'responds with the correct meeting info for a post request' do
        server = create(:server)
        meeting = create(:meeting, server: server)

        stub_request(:get, encode_bbb_uri("getMeetingInfo", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>")

        post bigbluebutton_api_get_meeting_info_url, params: { meetingID: meeting.id }

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
        expect(response_xml.at_xpath("/response/meetingID").content).to(eq("test-meeting-1"))
      end

      it 'responds with the correct meeting info for a post request with checksum value computed using SHA1' do
        server = create(:server)
        meeting = create(:meeting, id: "SHA1_meeting", server: server)

        stub_request(:get, encode_bbb_uri("getMeetingInfo", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetingID>SHA1_meeting</meetingID></response>")

        allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(["test-2"]) # TODO this does not seem to do anything

        post bigbluebutton_api_get_meeting_info_url, params: { meetingID: meeting.id, checksum: "cbf00ea96fae6ff06c2cb311bbde8b26ad66d765" }

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(response_xml.at_xpath('/response/meetingID').text).to eq('SHA1_meeting')
      end

      it 'responds with the correct meeting info for a post request with checksum value computed using SHA256' do
        server = create(:server)
        meeting = create(:meeting, id: "SHA256_meeting", server: server)

        stub_request(:get, encode_bbb_uri("getMeetingInfo", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetingID>SHA256_meeting</meetingID></response>")

        allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(["test-1"]) # TODO this does not seem to do anything

        post bigbluebutton_api_get_meeting_info_url, params: { meetingID: "SHA256_meeting", checksum: "217da05b692320353e17a1b11c24e9e715caeee51ab5af35231ee5becc350d1e" }

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(response_xml.at_xpath('/response/meetingID').text).to eq('SHA256_meeting')
      end
    end
  end

  describe '#is_meeting_running' do
    context '#GET is_meeting_running' do

    end

    context '#POST is_meeting_running' do

    end
  end
end
