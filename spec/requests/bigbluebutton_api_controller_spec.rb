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
        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/build')).to_not be_present
      end
    end

    context 'POST request' do
      before { post bigbluebutton_api_url }

      include_examples 'returns success XML response'

      it 'does not return build' do
        response_xml = Nokogiri::XML(response.body)
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
        response_xml = Nokogiri::XML(response.body)
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

        response_xml = Nokogiri.XML(response.body)
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

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
        expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to access server."))
      end

      it 'responds with noMeetings if there are no meetings on any server' do
        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(response.body)
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

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]")).not_to be_present
      end

      it 'only makes a request to online servers in state cordoned/enabled' do
        server1 = create(:server, state: "cordoned")
        server2 = create(:server, state: "enabled")
        create(:server, online: false)
        create(:server, state: "disabled")

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(response.body)
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

      # TODO those two specs are not working
      # TODO FIND A WAY TO BYPASS THE GLOBAL BEFORE BLOC THAT REMOVES THE CHECKSUM
      it 'responds with the correct meeting info for a post request with checksum value computed using SHA1' do
        server = create(:server, secret: 'test-1')
        meeting = create(:meeting, id: "SHA1_meeting", server: server)

        stub_request(:get, encode_bbb_uri("getMeetingInfo", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetingID>SHA1_meeting</meetingID></response>")

        allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['test-2']) # TODO this does not seem to do anything

        checksum = get_checksum("getMeetingInfo" + + server.secret, "SHA1")

        post bigbluebutton_api_get_meeting_info_url, params: { meetingID: meeting.id, checksum: "cbf00ea96fae6ff06c2cb311bbde8b26ad66d765" }

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(response_xml.at_xpath('/response/meetingID').text).to eq('SHA1_meeting')
      end

      it 'responds with the correct meeting info for a post request with checksum value computed using SHA256' do
        server = create(:server, secret: 'test-1')
        meeting = create(:meeting, id: "SHA256_meeting", server: server)

        stub_request(:get, encode_bbb_uri("getMeetingInfo", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetingID>SHA256_meeting</meetingID></response>")

        allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['test-1']) # TODO this does not seem to do anything

        post bigbluebutton_api_get_meeting_info_url, params: { meetingID: "SHA256_meeting", checksum: "217da05b692320353e17a1b11c24e9e715caeee51ab5af35231ee5becc350d1e" }

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(response_xml.at_xpath('/response/meetingID').text).to eq('SHA256_meeting')
      end
    end
  end

  describe '#is_meeting_running' do
    context '#GET request' do
      it "responds with the correct meeting status for a get request" do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server)

        stub_request(:get, encode_bbb_uri("isMeetingRunning", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><running>true</running></response>")

        get bigbluebutton_api_is_meeting_running_url, params: { meetingID: meeting.id }

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
        expect(response_xml.at_xpath("/response/running").content).to be_present
      end

      it "responds with appropriate error on timeout" do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server)

        stub_request(:get, encode_bbb_uri("isMeetingRunning", server.url, server.secret, meetingID: meeting.id))
          .to_timeout

        get bigbluebutton_api_is_meeting_running_url, params: { meetingID: meeting.id }

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
        expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to access meeting on server."))
      end

      it "responds with MissingMeetingIDError if meeting ID is not passed to isMeetingRunning" do
        get bigbluebutton_api_is_meeting_running_url

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MissingMeetingIDError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "responds with false if meeting is not found in database for isMeetingRunning" do
        get bigbluebutton_api_is_meeting_running_url, params: { meetingID: "test" }

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.at_xpath("/response/running").text).to(eq("false"))
      end
    end

    context '#POST is_meeting_running' do
      it 'responds with the correct meeting status for a post request' do
        server = create(:server)
        meeting = create(:meeting, server: server)

        stub_request(:get, encode_bbb_uri("isMeetingRunning", server.url, server.secret, meetingID: meeting.id))
          .to_return(body: "<response><returncode>SUCCESS</returncode><running>true</running></response>")

        post bigbluebutton_api_is_meeting_running_url, params: { meetingID: meeting.id }

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("SUCCESS")
        expect(response_xml.at_xpath("/response/running").text).to eq("true")
      end
    end
  end

  describe '#get_meetings' do
    context 'GET request' do
      it 'responds with the correct meetings for a get request' do
        server1 = create(:server)
        server2 = create(:server)

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1</meeting></meetings></response>")

        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2</meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("SUCCESS")
        expect(response_xml.xpath("//meeting[text()='test-meeting-1']")).to be_present
        expect(response_xml.xpath("//meeting[text()='test-meeting-2']")).to be_present
      end

      it 'getMeetings responds with appropriate error on timeout' do
        server1 = create(:server)
        server2 = create(:server)
        server3 = create(:server)

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1</meeting></meetings></response>")

        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_timeout

        stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3</meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("FAILED")
        expect(response_xml.at_xpath("/response/messageKey").text).to eq("internalError")
        expect(response_xml.at_xpath("/response/message").text).to eq("Unable to access server.")
      end

      it "responds with noMeetings if there are no meetings on any server" do
        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("SUCCESS")
        expect(response_xml.at_xpath("/response/messageKey").text).to eq("noMeetings")
        expect(response_xml.at_xpath("/response/message").text).to eq("no meetings were found on this server")
        expect(response_xml.at_xpath("/response/meetings").text).to eq("")
      end

      it "getMeetings only makes a request to online and enabled servers" do
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

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("SUCCESS")
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]")).to be_empty
      end


      it "only makes a request to servers that are online and in state cordoned or enabled" do
        server1 = create(:server, state: "cordoned")
        server2 = create(:server, state: "enabled")
        create(:server, online: false)
        create(:server, state: "disabled")

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")

        get bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("SUCCESS")
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]").present?).to eq(true)
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]")).to be_empty
      end

      it "returns no meetings if GET_MEETINGS_API_DISABLED flag is set to true for a get request" do
        mock_env("GET_MEETINGS_API_DISABLED" => "TRUE") do
          reload_routes!
          get bigbluebutton_api_get_meetings_url
        end

        response_xml = Nokogiri::XML(response.body)
        expect(response).to have_http_status(:success)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("SUCCESS")
        expect(response_xml.at_xpath("/response/messageKey").text).to eq("noMeetings")
        expect(response_xml.at_xpath("/response/message").text).to eq("no meetings were found on this server")
        expect(response_xml.at_xpath("/response/meetings").text).to eq("")
      end

    end

    context 'POST request' do
      it "responds with the correct meetings for a post request" do
        server1 = create(:server)
        server2 = create(:server)

        stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
        stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret))
          .to_return(body: "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")

        post bigbluebutton_api_get_meetings_url

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]")).to be_present
        expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]")).to be_present
      end

      it "returns no meetings if GET_MEETINGS_API_DISABLED flag is set to true for a post request" do
        mock_env("GET_MEETINGS_API_DISABLED" => "TRUE") do
          reload_routes!
          post bigbluebutton_api_get_meetings_url
        end

        response_xml = Nokogiri::XML(response.body)
        expect(response).to have_http_status(:success)
        expect(response_xml.at_xpath("/response/returncode").text).to eq("SUCCESS")
        expect(response_xml.at_xpath("/response/messageKey").text).to eq("noMeetings")
        expect(response_xml.at_xpath("/response/message").text).to eq("no meetings were found on this server")
        expect(response_xml.at_xpath("/response/meetings").text).to eq("")
      end
    end

    describe '#create' do
      # before do
      #   # We need to set this to stub this to true unless we want a random voice bridge to be generated every spec
      #   allow(Rails.configuration.x).to receive(:use_external_voice_bridge).and_return(true)
      # end

      context 'GET request' do
        it "responds with MissingMeetingIDError if meeting ID is not passed to create" do
          get bigbluebutton_api_create_url

          response_xml = Nokogiri.XML(response.body)
          expected_error = BBBErrors::MissingMeetingIDError.new
          expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
          expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
          expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
        end

        it "responds with InternalError if no servers are available in create" do
          get bigbluebutton_api_create_url, params: { meetingID: "test-meeting-1" }

          response_xml = Nokogiri.XML(response.body)
          expected_error = BBBErrors::InternalError.new("Could not find any available servers.")
          expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
          expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
          expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
        end

        # TODO - those methods I dont understand. Do not seem to test anything. They do not need voiceBridge also?
        # TODO - they have been added recently: https://github.com/blindsidenetworks/scalelite/commit/b2779be67175392663a3e2e64f034ea0aa3b65d9
        it 'creates the meeting successfully for a get request' do
          server = create(:server, load: 0)

          params = {
            meetingID: 'test-meeting-1', moderatorPW: 'mp',
          }

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including(params))
            .to_return do |request|
                request_params = URI.decode_www_form(request.uri.query)
                expect(request_params.assoc('voiceBridge').last).to match(/\A[1-9][0-9]{8}\z/)

                { body: meeting_create_response(params[:meetingID], params[:moderatorPW]) }
            end

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          # Reload
          server = Server.find(server.id)
          meeting = Meeting.find(params[:meetingID])

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
          expect(meeting.id).to eq(params[:meetingID])
          expect(meeting.server.id).to eq(server.id)
          expect(server.load).to eq(1)
        end

        it "returns an appropriate error on timeout" do
          server = create(:server, load: 0)
          params = { meetingID: "test-meeting-1", moderatorPW: "mp" }

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including(params))
            .to_timeout

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').content).to eq('FAILED')
          expect(response_xml.at_xpath('/response/messageKey').content).to eq('internalError')
          expect(response_xml.at_xpath('/response/message').content).to eq('Unable to create meeting on server.')
        end

        it "increments the server load by the value of load_multiplier" do
          server = create(:server, load: 0, load_multiplier: 7.0)
          params = { meetingID: "test-meeting-1", moderatorPW: "mp" }

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including(params))
            .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          # Reload
          server = Server.find(server.id)
          expect(server.load).to eq(7)
        end

        it "sets the duration param to MAX_MEETING_DURATION if set" do
          server = create(:server, load: 0)

          params = { meetingID: 'test-meeting-1', moderatorPW: 'test-password' }

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including(params.merge(duration: '3600')))
            .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

          allow(Rails.configuration.x).to receive(:max_meeting_duration).and_return(3600)

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        end

        it "sets the duration param to MAX_MEETING_DURATION if passed duration is greater than MAX_MEETING_DURATION" do
          server = create(:server, load: 0)

          params = {
            duration: 5000,
            meetingID: 'test-meeting-1',
            moderatorPW: 'test-password',
          }

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including(params.merge(duration: '3600')))
            .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

          allow(Rails.configuration.x).to receive(:max_meeting_duration).and_return(3600)

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        end

        it 'sets the duration param to MAX_MEETING_DURATION if passed duration is 0' do
          server = create(:server, load: 0)

          params = {
            duration: 0,
            meetingID: 'test-meeting-1',
            moderatorPW: 'test-password',
          }

          bbb_create = stub_request(:get, "#{server.url}create")
                       .with(query: hash_including(params.merge(duration: '3600')))
                       .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

          allow(Rails.configuration.x).to receive(:max_meeting_duration).and_return(3600)

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        end

        it 'does not set the duration param to MAX_MEETING_DURATION if passed duration is less than MAX_MEETING_DURATION' do
          server = create(:server, load: 0)

          params = {
            duration: '1200',
            meetingID: 'test-meeting-1',
            moderatorPW: 'test-password',
          }

          bbb_create = stub_request(:get, "#{server.url}create")
                       .with(query: hash_including(params))
                       .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        end

        it 'creates the room successfully with only permitted params for create' do
          server = create(:server, load: 0)

          params = {
            meetingID: 'test-meeting-1', test4: '', test2: '', moderatorPW: 'test-password',
          }

          bbb_create = stub_request(:get, "#{server.url}create")
                       .with(query: hash_including({}))
                       .to_return do |request|
            request_params = URI.decode_www_form(request.uri.query)
            expect(request_params.assoc('meetingID').last).to eq(params[:meetingID])
            expect(request_params.assoc('moderatorPW').last).to eq(params[:moderatorPW])
            expect(request_params.assoc('voiceBridge').last).to match(/[1-9][0-9]{8}/)
            # Filtered params:
            expect(request_params.assoc('test4')).to be_nil
            expect(request_params.assoc('test2')).to be_nil

            { body: meeting_create_response(params[:meetingID], params[:moderatorPW]) }
          end

          allow(Rails.configuration.x).to receive(:create_exclude_params).and_return(%w[test4 test2])

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          # Reload
          server = Server.find(server.id)
          meeting = Meeting.find(params[:meetingID])

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
          expect(meeting.id).to eq(params[:meetingID])
          expect(meeting.server.id).to eq(server.id)
          expect(server.load).to eq(1)
        end

        it 'creates the room successfully with given params if excluded params list is empty' do
          server = create(:server, load: 0)

          params = {
            meetingID: 'test-meeting-1', test4: '', test2: '', moderatorPW: 'test-password',
          }

          bbb_create = stub_request(:get, "#{server.url}create")
                       .with(query: hash_including(params))
                       .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          # Reload
          server = Server.find(server.id)
          meeting = Meeting.find(params[:meetingID])

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
          expect(meeting.id).to eq(params[:meetingID])
          expect(meeting.server.id).to eq(server.id)
          expect(server.load).to eq(1)
        end

      #   it "creates the room successfully with given params if excluded params list is empty" do
      #     server1 = create(:server, url: 'https://test-1.example.com/bigbluebutton/api/',
      #                      secret: 'test-1-secret', enabled: true, load: 0)
      #
      #     params = {
      #       meetingID: 'test-meeting-1', test4: '', test2: '', moderatorPW: 'test-password',
      #     }
      #
      #     bbb_create = \
      # stub_request(:get, "#{server1.url}create")
      #                          .with(query: hash_including(params))
      #                          .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))
      #
      #     mocked_method = instance_double("MockedMethod")
      #     return_value = { meetingID: 'test-meeting-1', test4: '', test2: '' }
      #
      #     allow(Rails.configuration.x).to receive(:create_exclude_params).and_return([])
      #     allow(mocked_method).to receive(:pass_through_params).with([]).and_return(return_value)
      #
      #     get bigbluebutton_api_create_url, params: params
      #
      #     expect(mocked_method).to have_received(:pass_through_params).with([])
      #
      #     expect(bbb_create).to have_been_requested
      #
      #     # Reload
      #     server1 = Server.find(server1.id)
      #     meeting = Meeting.find(params[:meetingID])
      #
      #     response_xml = Nokogiri::XML(@response.body)
      #     expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
      #     expect(meeting.id).to eq(params[:meetingID])
      #     expect(meeting.server.id).to eq(server1.id)
      #     expect(server1.load).to eq(1)
      #   end

        it 'creates a record in callback_data if params["meta_bn-recording-ready-url"] is present in request' do
          server = create(:server, load: 0)
          params = {
            meetingID: 'test-meeting-1', test4: '', test2: '', moderatorPW: 'test-password',
            'meta_bn-recording-ready-url' => 'https://test-2.example.com/recording-ready/',
          }

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including({}))
            .to_return do |request|
                  request_params = URI.decode_www_form(request.uri.query)
                  expect(request_params.assoc('meetingID').last).to eq(params[:meetingID])
                  expect(request_params.assoc('test4').last).to eq(params[:test4])
                  expect(request_params.assoc('test2').last).to eq(params[:test2])
                  expect(request_params.assoc('moderatorPW').last).to eq(params[:moderatorPW])
                  expect(request_params.assoc('meta_bn-recording-ready-url')).to be_nil

                  { body: meeting_create_response(params[:meetingID], params[:moderatorPW]) }
                end

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')

          callback_data = CallbackData.find_by(meeting_id: params[:meetingID])
          expect(callback_data.callback_attributes).to eq({ recording_ready_url: params['meta_bn-recording-ready-url'] })
        end

        it 'creates a record in callback_data if params["meta_analytics-callback-url"] is present in request' do
          server = create(:server, load: 0)
          params = {
            meetingID: 'test-meeting-66', test4: '', test2: '', moderatorPW: 'test-password',
            'meta_analytics-callback-url' => 'https://example.com/analytics_callback',
          }

          allow(Rails.configuration.x).to receive(:url_host).and_return('test.scalelite.com')

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including(
              params.merge(
                'meta_analytics-callback-url' => \
                  "https://#{Rails.configuration.x.url_host}#{bigbluebutton_api_analytics_callback_path}"
              )
            ))
            .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested

          response_xml = Nokogiri::XML(response.body)
          expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')

          callback_data = CallbackData.find_by(meeting_id: params[:meetingID])
          expect(callback_data.callback_attributes).to eq({ analytics_callback_url: params['meta_analytics-callback-url'] })
        end

        it 'create sets default params if they are not already set' do
          server = create(:server, load: 0)
          params = {
            meetingID: 'test-meeting-1',
            param1: 'param1',
          }
          default_params = {
            param1: 'not-param1',
            param2: 'param2',
          }

          bbb_create = \
            stub_request(:get, "#{server.url}create")
            .with(query: hash_including(default_params.merge(params)))
            .to_return(body: meeting_create_response(params[:meetingID]))

          allow(Rails.configuration.x).to receive(:default_create_params).and_return(default_params)

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested
        end

        it 'sets override params even if they are set' do
          server = create(:server, load: 0)
          params = {
            meetingID: 'test-meeting-1',
            param1: 'not-param1',
          }
          override_params = {
            param1: 'param1',
            param2: 'param2',
          }

          bbb_create = stub_request(:get, "#{server.url}create")
                       .with(query: hash_including(params.merge(override_params)))
                       .to_return(body: meeting_create_response(params[:meetingID]))

          allow(Rails.configuration.x).to receive(:override_create_params).and_return(override_params)

          get bigbluebutton_api_create_url, params: params

          expect(bbb_create).to have_been_requested
        end
      end
    end

    context 'POST request' do
      it 'creates the meeting successfully for a post request' do
        # TODO investigate this
        skip('scalelite does not correctly handle request params in post requests')

        server = create(:server, load: 0)

        params = {
          meetingID: 'test-meeting-1', moderatorPW: 'mp',
        }

        bbb_create = \
          stub_request(:post, "#{server.url}create")
          .with(query: hash_including({}))
          .to_return do |request|
              expect(request.uri.query).to be_nil

              request_params = URI.decode_www_form(request.body)
              expect(request_params.assoc('meetingID').last).to eq(params[:meetingID])
              expect(request_params.assoc('moderatorPW').last).to eq(params[:moderatorPW])
              expect(request_params.assoc('voiceBridge').last).to match(/\A[1-9][0-9]{8}\z/)

              { body: meeting_create_response(params[:meetingID], params[:moderatorPW]) }
          end

        post bigbluebutton_api_create_url, params: params

        expect(bbb_create).to have_been_requested

        # Reload
        server = Server.find(server.id)
        meeting = Meeting.find(params[:meetingID])

        response_xml = Nokogiri::XML(response.body)
        expect(response_xml.at_xpath('/response/returncode').text).to eq('SUCCESS')
        expect(meeting.id).to eq(params[:meetingID])
        expect(meeting.server.id).to eq(server.id)
        expect(server.load).to eq(1)
      end
    end
  end

  describe '#analytics_callback' do
    it "analytics_callback makes a callback to the specific meetings analytics_callback_url stored in callback_attributes table" do
      server1 = create(:server, url: 'https://test-1.example.com/bigbluebutton/api/',
                       secret: 'test-1-secret', enabled: true, load: 0)
      params = {
        meetingID: 'test-meeting-1111', test4: '', test2: '', moderatorPW: 'test-password',
        'meta_analytics-callback-url' => 'https://callback.example.com/analytics_callback',
      }

      stub_request(:get, "#{server1.url}create")
        .with(query: hash_including({}))
        .to_return(body: meeting_create_response(params[:meetingID], params[:moderatorPW]))

      callback = stub_request(:post, params['meta_analytics-callback-url'])
                   .to_return(status: :ok, body: '', headers: {})

      allow_any_instance_of(BigBlueButtonApiController).to receive(:verify_checksum).and_return(nil)
      allow_any_instance_of(BigBlueButtonApiController).to receive(:valid_token?).and_return(true)
      allow(Rails.configuration.x).to receive(:url_host).and_return('test.scalelite.com')

      get bigbluebutton_api_create_url, params: params
      post bigbluebutton_api_analytics_callback_url, params: { meeting_id: 'test-meeting-1111' }, headers: { 'HTTP_AUTHORIZATION' => 'Bearer ABCD' }

      expect(@response.status).to eq(204)
      expect(callback).to have_been_requested
      callback_data = CallbackData.find_by(meeting_id: params[:meetingID])
      expect(callback_data.callback_attributes).to eq({ analytics_callback_url: params['meta_analytics-callback-url'] })
    end
  end

  describe '#end' do
    context 'GET request' do
      it "responds with MissingMeetingIDError if meeting ID is not passed to end" do
        get bigbluebutton_api_end_url

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MissingMeetingIDError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "responds with MeetingNotFoundError if meeting is not found in database for end" do
        get bigbluebutton_api_end_url, params: { meetingID: "test-meeting-1" }

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MeetingNotFoundError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "responds with MeetingNotFoundError if meetingID && password are passed but meeting doesnt exist" do
        server = create(:server, load: 0)
        params = { meetingID: "test-meeting-1", password: "test-password" }

        stub_request(:get, encode_bbb_uri("end", server.url, server.secret, params))
          .to_return(body: "<response><returncode>FAILED</returncode><messageKey>notFound</messageKey><message>We could not find a meeting with that meeting ID - perhaps the meeting is not yet running?</message></response>")

        get(bigbluebutton_api_end_url, params: params)

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MeetingNotFoundError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "responds with sentEndMeetingRequest if meeting exists and password is correct for a get request" do
        server = create(:server, load: 0)
        create(:meeting, server: server, moderator_pw: "mp")
        params = { meetingID: "test-meeting-1", password: "test-password" }

        stub_request(:get, encode_bbb_uri("end", server.url, server.secret, params))
          .to_return(body: "<response><returncode>SUCCESS</returncode><messageKey>sentEndMeetingRequest</messageKey><message>A request to end the meeting was sent. Please wait a few seconds, and then use the getMeetingInfo or isMeetingRunning API calls to verify that it was ended.</message></response>")

        get bigbluebutton_api_end_url, params: params

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq("sentEndMeetingRequest"))
        expect { Meeting.find("test-meeting-1") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
      end

      it("end returns error on timeout but still deletes meeting") do
        server = create(:server, load: 0)
        create(:meeting, server: server, moderator_pw: "mp")
        params = { meetingID: "test-meeting-1", password: "test-password" }

        stub_request(:get, encode_bbb_uri("end", server.url, server.secret, params))
          .to_timeout

        get bigbluebutton_api_end_url, params: params

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq("internalError"))
        expect(response_xml.at_xpath("/response/message").text).to(eq("Unable to access meeting on server."))
        expect { Meeting.find("test-meeting-1") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
      end
    end

    context 'POST request' do
      it "responds with sentEndMeetingRequest if meeting exists and password is correct for a post request" do
        server = create(:server, load: 0)
        create(:meeting, server: server, moderator_pw: "mp")
        params = { meetingID: "test-meeting-1", password: "test-password" }

        stub_request(:get, encode_bbb_uri("end", server.url, server.secret, params))
          .to_return(body: "<response><returncode>SUCCESS</returncode><messageKey>sentEndMeetingRequest</messageKey><message>A request to end the meeting was sent. Please wait a few seconds, and then use the getMeetingInfo or isMeetingRunning API calls to verify that it was ended.</message></response>")

        post bigbluebutton_api_end_url, params: params

        response_xml = Nokogiri.XML(response.body)
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq("sentEndMeetingRequest"))
        expect { Meeting.find("test-meeting-1") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
      end
    end
  end

  describe '#join' do
    context 'GET request' do
      it "responds with MissingMeetingIDError if meeting ID is not passed to join" do
        get bigbluebutton_api_join_url

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MissingMeetingIDError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "responds with MeetingNotFoundError if meeting is not found in database for join" do
        get bigbluebutton_api_join_url, params: { meetingID: "test-meeting-1" }

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::MeetingNotFoundError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "redirects user to the correct join url for a get request" do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server, moderator_pw: "mp")
        params = { meetingID: meeting.id, password: "test-password", fullName: "test-name" }

        get bigbluebutton_api_join_url, params: params
        expect(response).to redirect_to(encode_bbb_uri("join", server.url, server.secret, params).to_s)
      end

      it "redirects user to the current join url with only permitted params for join" do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server, moderator_pw: "mp")
        params = { meetingID: meeting.id, password: "test-password", fullName: "test-name", test1: "", test2: "" }

        allow(Rails.configuration.x).to receive(:join_exclude_params).and_return(%w[test1 test2])

        get bigbluebutton_api_join_url, params: params

        filtered_params = { meetingID: meeting.id, password: "test-password", fullName: "test-name" }
        expect(response).to redirect_to(encode_bbb_uri("join", server.url, server.secret, filtered_params).to_s)
      end

      it 'redirects user to the current join url with given params if excluded params list is empty' do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server, moderator_pw: "mp")
        params = { meetingID: meeting.id, password: 'test-password', fullName: 'test-name', test1: '', test2: '' }

        # TODO this is initially set to stub an empty array return but the expected return below (comment out) is [test1, test2]
        allow(Rails.configuration.x).to receive(:join_exclude_params).and_return([])

        get bigbluebutton_api_join_url, params: params

        expect(response).to redirect_to encode_bbb_uri('join', server.url, server.secret, params).to_s
        # filtered_params = { meetingID: meeting.id, password: 'test-password', fullName: 'test-name' }
        # expect(Rails.configuration.x.join_exclude_params).to eq(%w[test1 test2])
        # expect(response).to redirect_to encode_bbb_uri('join', server.url, server.secret, filtered_params).to_s
      end

      it "responds with ServerUnavailableError if server is disabled" do
        server = create(:server, load: 0, enabled: false)
        create(:meeting, server: server, moderator_pw: "mp")

        get bigbluebutton_api_join_url, params: { meetingID: "test-meeting-1" }

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::ServerUnavailableError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "responds with ServerUnavailableError if server is offline" do
        server = create(:server, load: 0, online: false)
        create(:meeting, server: server, moderator_pw: "mp")

        get bigbluebutton_api_join_url, params: { meetingID: "test-meeting-1" }

        response_xml = Nokogiri.XML(response.body)
        expected_error = BBBErrors::ServerUnavailableError.new
        expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
        expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
        expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
      end

      it "sets default params if they are not already set" do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server, moderator_pw: "mp")
        params = {
          meetingID: meeting.id,
          moderatorPW: 'mp',
          fullName: 'test-name',
          param1: 'param1'
        }
        default_params = {
          param1: 'not-param1',
          param2: 'param2',
        }

        allow(Rails.configuration.x).to receive(:default_join_params).and_return(default_params)

        get bigbluebutton_api_join_url, params: params

        expect(response.headers['Location']).to start_with(server.url)
        redirect_url = URI(response.headers['Location'])
        redirect_params = URI.decode_www_form(redirect_url.query)
        expect(redirect_params.assoc('param1').last).to eq(params[:param1])
        expect(redirect_params.assoc('param2').last).to eq(default_params[:param2])
      end

      it "sets override params even if they are set" do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server, moderator_pw: "mp")
        params = {
          meetingID: meeting.id,
          moderatorPW: 'mp',
          fullName: 'test-name',
          param1: 'not-param1'
        }
        override_params = {
          param1: 'param1',
          param2: 'param2',
        }

        allow(Rails.configuration.x).to receive(:override_join_params).and_return(override_params)

        get bigbluebutton_api_join_url, params: params

        expect(response.headers['Location']).to start_with(server.url)
        redirect_url = URI(response.headers['Location'])
        redirect_params = URI.decode_www_form(redirect_url.query)
        expect(redirect_params.assoc('param1').last).to eq(override_params[:param1])
        expect(redirect_params.assoc('param2').last).to eq(override_params[:param2])
      end
    end

    context 'POST request' do
      it "redirects user to the correct join url for a post request" do
        server = create(:server, load: 0)
        meeting = create(:meeting, server: server, moderator_pw: "mp")
        params = { meetingID: meeting.id, password: "test-password", fullName: "test-name" }

        post bigbluebutton_api_join_url, params: params

        expect(response).to redirect_to(encode_bbb_uri("join", server.url, server.secret, params).to_s)
      end
    end
  end

  describe '#get_recordings' do
    context 'GET request' do
      # TODO undo the checksum bypass for this test
      xit "with no parameters returns checksum error" do
        get bigbluebutton_api_get_recordings_url

        expect(response).to have_http_status(:success)

        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("FAILED")
        expect(xml_response.xpath("//response/messageKey").text).to eq("checksumError")
      end

      # TODO undo the checksum bypass for this test
      xit "with invalid checksum returns checksum error" do
        get bigbluebutton_api_get_recordings_url, params: "checksum=#{'x' * 40}"

        expect(response).to have_http_status(:success)

        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("FAILED")
        expect(xml_response.xpath("//response/messageKey").text).to eq("checksumError")
      end

      it "with only checksum returns all recordings for a get request" do
        create_list(:recording, 3, state: "published")
        params = encode_bbb_params("getRecordings", "")
        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)

        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(3)
      end

      it "with get_recordings_api_filtered does not return any recordings and returns error response if no meetingId/recordId is provided" do
        create_list(:recording, 3, state: "published")
        params = encode_bbb_params("getRecordings", "")

        allow(Rails.configuration.x).to receive(:get_recordings_api_filtered).and_return(true)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)

        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("FAILED")
        expect(xml_response.xpath("//response/messageKey").text).to eq("missingParameters")
        expect(xml_response.xpath("//response/message").text).to eq("param meetingID or recordID must be included.")
      end

      it "fetches recording by meeting id" do
        r = create(:recording, :published, participants: 3, state: "published")
        podcast = create(:playback_format, recording: r, format: "podcast")
        presentation = create(:playback_format, recording: r, format: "presentation")
        params = encode_bbb_params("getRecordings", { meetingID: r.meeting_id }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        url_prefix = "#{request.protocol}#{request.host}"

        expect(response).to have_http_status(:success)

        xml_response = Nokogiri::XML(response.body)

        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(1)

        parsed_response = Nokogiri::XML(response.body)
        rec_el = parsed_response.at_css("response>recordings>recording")

        expect(rec_el.at_css("recordID").content).to eq(r.record_id)
        expect(rec_el.at_css("meetingID").content).to eq(r.meeting_id)
        expect(rec_el.at_css("internalMeetingID").content).to eq(r.record_id)
        expect(rec_el.at_css("name").content).to eq(r.name)
        expect(rec_el.at_css("published").content).to eq("true")
        expect(rec_el.at_css("state").content).to eq("published")
        expect(rec_el.at_css("startTime").content).to eq((r.starttime.to_r * 1000).to_i.to_s)
        expect(rec_el.at_css("endTime").content).to eq((r.endtime.to_r * 1000).to_i.to_s)
        expect(rec_el.at_css("participants").content).to eq("3")
        expect(rec_el.css("playback>format").size).to eq(r.playback_formats.count)

        format_els = rec_el.css("playback>format")
        format_els.each do |format_el|
          format_type = format_el.at_css("type").content
          pf = nil
          case format_type
          when "podcast"
            pf = podcast
          when "presentation"
            pf = presentation
          else
            raise "Unexpected playback format: #{format_type}"
          end
          expect(format_el.at_css("type").content).to eq(pf.format)
          expect(format_el.at_css("url").content).to eq("#{url_prefix}#{pf.url}")
          expect(format_el.at_css("length").content).to eq(pf.length.to_s)
          expect(format_el.at_css("processingTime").content).to eq(pf.processing_time.to_s)

          imgs = format_el.css("preview>images>image")
          expect(pf.thumbnails.count).to eq(imgs.size)
          imgs.each_with_index do |img, i|
            t = thumbnails("fred_room_#{pf.format}_thumb#{i + 1}")
            expect(img['alt']).to eq(t.alt)
            expect(img['height']).to eq(t.height.to_s)
            expect(img['width']).to eq(t.width.to_s)
            expect("#{url_prefix}#{t.url}").to eq(img.content)
          end
        end
      end

      it "with get_recordings_api_filtered fetches recording by meeting id" do
        r = create(:recording, :published, participants: 3, state: "published")
        podcast = create(:playback_format, recording: r, format: "podcast")
        presentation = create(:playback_format, recording: r, format: "presentation")
        params = encode_bbb_params("getRecordings", { meetingID: r.meeting_id }.to_query)

        allow(Rails.configuration.x).to receive(:get_recordings_api_filtered).and_return(true)

        get bigbluebutton_api_get_recordings_url, params: params

        url_prefix = "#{request.protocol}#{request.host}"

        expect(response).to have_http_status(:success)

        xml_response = Nokogiri::XML(response.body)

        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(1)

        parsed_response = Nokogiri::XML(response.body)
        rec_el = parsed_response.at_css("response>recordings>recording")

        expect(rec_el.at_css("recordID").content).to eq(r.record_id)
        expect(rec_el.at_css("meetingID").content).to eq(r.meeting_id)
        expect(rec_el.at_css("internalMeetingID").content).to eq(r.record_id)
        expect(rec_el.at_css("name").content).to eq(r.name)
        expect(rec_el.at_css("published").content).to eq("true")
        expect(rec_el.at_css("state").content).to eq("published")
        expect(rec_el.at_css("startTime").content).to eq((r.starttime.to_r * 1000).to_i.to_s)
        expect(rec_el.at_css("endTime").content).to eq((r.endtime.to_r * 1000).to_i.to_s)
        expect(rec_el.at_css("participants").content).to eq("3")
        expect(rec_el.css("playback>format").size).to eq(r.playback_formats.count)

        format_els = rec_el.css("playback>format")
        format_els.each do |format_el|
          format_type = format_el.at_css("type").content
          pf = nil
          case format_type
          when "podcast"
            pf = podcast
          when "presentation"
            pf = presentation
          else
            raise "Unexpected playback format: #{format_type}"
          end
          expect(format_el.at_css("type").content).to eq(pf.format)
          expect(format_el.at_css("url").content).to eq("#{url_prefix}#{pf.url}")
          expect(format_el.at_css("length").content).to eq(pf.length.to_s)
          expect(format_el.at_css("processingTime").content).to eq(pf.processing_time.to_s)

          imgs = format_el.css("preview>images>image")
          expect(pf.thumbnails.count).to eq(imgs.size)
          imgs.each_with_index do |img, i|
            t = thumbnails("fred_room_#{pf.format}_thumb#{i + 1}")
            expect(img['alt']).to eq(t.alt)
            expect(img['height']).to eq(t.height.to_s)
            expect(img['width']).to eq(t.width.to_s)
            expect("#{url_prefix}#{t.url}").to eq(img.content)
          end
        end
      end

      it "allows multiple comma-separated meeting IDs" do
        create_list(:recording, 5, state: "published")
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "published")
        params = encode_bbb_params("getRecordings", { meetingID: [r1.meeting_id, r2.meeting_id].join(",") }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(2)
      end

      it "with get_recordings_api_filtered allows multiple comma-separated meeting IDs" do
        create_list(:recording, 5, state: "published")
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "published")
        params = encode_bbb_params("getRecordings", { meetingID: [r1.meeting_id, r2.meeting_id].join(",") }.to_query)

        allow(Rails.configuration.x).to receive(:get_recordings_api_filtered).and_return(true)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(2)
      end

      it "does case-sensitive match on recording id" do
        r = create(:recording, state: "published")
        params = encode_bbb_params("getRecordings", { recordID: r.record_id.upcase }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/messageKey").text).to eq("noRecordings")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(0)
      end

      it "does prefix match on recording id" do
        create_list(:recording, 5, state: "published")
        r = create(:recording, meeting_id: "bulk-prefix-match", state: "published")
        create_list(:recording, 19, meeting_id: "bulk-prefix-match", state: "published")
        params = encode_bbb_params("getRecordings", { recordID: r.record_id[0, 40] }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(20)
        expect(xml_response.xpath("//recording/meetingID[text() = '#{r.meeting_id}']").count).to eq(20)
      end

      it "allows multiple comma-separated recording IDs" do
        create_list(:recording, 5, state: "published")
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "published")
        params = encode_bbb_params("getRecordings", { recordID: [r1.record_id, r2.record_id].join(",") }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(2)
      end

      it "with get_recordings_api_filtered allows multiple comma-separated recording IDs" do
        create_list(:recording, 5, state: "published")
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "published")
        params = encode_bbb_params("getRecordings", { recordID: [r1.record_id, r2.record_id].join(",") }.to_query)

        allow(Rails.configuration.x).to receive(:get_recordings_api_filtered).and_return(true)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.at_xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(2)
      end

      it "filters based on recording states" do
        create_list(:recording, 5)
        r1 = create(:recording, state: "processing")
        r2 = create(:recording, state: "unpublished")
        r3 = create(:recording, state: "deleted")
        params = encode_bbb_params("getRecordings", { recordID: [r1.record_id, r2.record_id, r3.record_id].join(","),
                                                      state: %w[published unpublished].join(",") }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.at_xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(1)
      end

      it "with get_recordings_api_filtered filters based on recording states" do
        create_list(:recording, 5, state: "deleted")
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "unpublished")
        r3 = create(:recording, state: "deleted")
        params = encode_bbb_params("getRecordings",
                                   { recordID: [r1.record_id, r2.record_id, r3.record_id].join(","),
                                     state: %w[published unpublished].join(",") }.to_query)

        allow(Rails.configuration.x).to receive(:get_recordings_api_filtered).and_return(true)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.at_xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(2)
      end

      it "filters based on recording states and meta_params" do
        create_list(:recording, 5, state: "processing")
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "unpublished")
        r3 = create(:recording, state: "deleted")
        create(:metadatum, recording: r1, key: "bbb-context-name", value: "test1")
        create(:metadatum, recording: r3, key: "bbb-origin-tag", value: "GL")
        create(:metadatum, recording: r2, key: "bbb-origin-tag", value: "GL")
        params = encode_bbb_params("getRecordings",
                                   { recordID: [r1.record_id, r2.record_id, r3.record_id].join(","), state: %w[published unpublished deleted].join(","),
                                     "meta_bbb-context-name": %w[test1 test2].join(","), "meta_bbb-origin-tag": ["GL"].join(",") }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.at_xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(3)
      end

      it "with get_recordings_api_filtered filters based on recording states and meta_params" do
        create_list(:recording, 5)
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "unpublished")
        r3 = create(:recording)
        create(:metadatum, recording: r1, key: "bbb-context-name", value: "test1")
        create(:metadatum, recording: r3, key: "bbb-origin-tag", value: "GL")
        create(:metadatum, recording: r2, key: "bbb-origin-tag", value: "GL")
        params = encode_bbb_params("getRecordings",
                                   { recordID: [r1.record_id, r2.record_id, r3.record_id].join(","), state: %w[published unpublished].join(","),
                                     "meta_bbb-context-name": %w[test1 test2].join(","), "meta_bbb-origin-tag": ["GL"].join(",") }.to_query)

        allow(Rails.configuration.x).to receive(:get_recordings_api_filtered).and_return(true)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.at_xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(2)
      end

      it "filters based on recording states and meta_params and returns no recordings if no match found" do
        create_list(:recording, 5)
        r1 = create(:recording, state: "published")
        r2 = create(:recording, state: "unpublished")
        r3 = create(:recording)
        create(:metadatum, recording: r1, key: "bbb-context-name", value: "test12")
        create(:metadatum, recording: r3, key: "bbb-origin-tag", value: "GL1")
        create(:metadatum, recording: r2, key: "bbb-origin-tag", value: "GL2")
        params = encode_bbb_params("getRecordings",
                                   { recordID: [r1.record_id, r2.record_id, r3.record_id].join(","), state: %w[published unpublished].join(","),
                                     "meta_bbb-context-name": %w[test1 test2].join(","), "meta_bbb-origin-tag": ["GL"].join(",") }.to_query)

        get bigbluebutton_api_get_recordings_url, params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.at_xpath("//response/returncode").text).to eq("SUCCESS")
        expect(xml_response.xpath("//response/recordings/recording").count).to eq(0)
      end
    end

    context 'POST request' do
      #this is where I am at
    end
  end

  describe '#publish_recordings' do
    context 'GET request' do
    end
    context 'POST request' do
    end
  end

  describe '#update_recordings' do
    context 'GET request' do
      it "returns notFound if RECORDING_DISABLED flag is set to true for a get request" do
        params = encode_bbb_params("updateRecordings", "")

        # TODO confirm why reload_routes is used only here after changing a config
        allow(Rails.configuration.x).to receive(:recording_disabled).and_return(true)
        reload_routes!

        get("http://www.example.com/bigbluebutton/api/updateRecordings", params: params)

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("FAILED")
        expect(xml_response.xpath("//response/messageKey").text).to eq("notFound")
        expect(xml_response.xpath("//response/message").text).to eq("We could not find recordings")
      end
    end
    context 'POST request' do
      it "returns notFound if RECORDING_DISABLED flag is set to true for a post request" do
        params = encode_bbb_params("updateRecordings", "")

        # TODO confirm why reload_routes is used only here after changing a config
        allow(Rails.configuration.x).to receive(:recording_disabled).and_return(true)
        reload_routes!

        post "http://www.example.com/bigbluebutton/api/updateRecordings", params: params

        expect(response).to have_http_status(:success)
        xml_response = Nokogiri::XML(response.body)
        expect(xml_response.xpath("//response/returncode").text).to eq("FAILED")
        expect(xml_response.xpath("//response/messageKey").text).to eq("notFound")
        expect(xml_response.xpath("//response/message").text).to eq("We could not find recordings")
      end
    end
  end

  describe '#delete_recordings' do
    context 'GET request' do
    end
    context 'POST request' do
    end
  end

  describe '#get_recordings' do #this is doubled
    context 'GET request' do
    end
    context 'POST request' do
    end
  end
end
