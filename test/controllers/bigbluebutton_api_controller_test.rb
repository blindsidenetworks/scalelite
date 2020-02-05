# frozen_string_literal: true

class BigBlueButtonApiControllerTest < ActionDispatch::IntegrationTest
  include BBBErrors
  include ApiHelper

  # /

  test 'responds with success and version' do
    get bigbluebutton_api_url

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal '2.0', response_xml.at_xpath('/response/version').text

    assert_response :success
  end

  # getMeetingInfo

  test 'responds with the correct meeting info' do
    server = Server.create!(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1')
    Meeting.create!(id: 'test-meeting-1', server: server)

    url = 'https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=a4eee985e3f1f9524a6e2a32d1e35d3703e4cef9'

    stub_request(:get, url)
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>')

    get bigbluebutton_api_get_meeting_info_url, params: { meetingID: 'test-meeting-1' }

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').content
    assert_equal 'test-meeting-1', response_xml.at_xpath('/response/meetingID').content
  end

  test 'responds with MeetingNotFound if meeting ID is not passed' do
    get bigbluebutton_api_get_meeting_info_url

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MeetingNotFoundError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with MeetingNotFoundError if meeting is not found in database' do
    get bigbluebutton_api_get_meeting_info_url, params: { meetingID: 'test' }

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MeetingNotFoundError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  # isMeetingRunning

  test 'responds with the correct meeting status' do
    server1 = Server.create(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret', load: 0)
    meeting1 = Meeting.find_or_create_with_server('Demo Meeting', server1)

    stub_request(:get, encode_bbb_uri('isMeetingRunning', server1.url, server1.secret, 'meetingID' => meeting1.id))
      .to_return(body: '<response><returncode>SUCCESS</returncode><running>true</running></response>')

    get bigbluebutton_api_is_meeting_running_url, params: { meetingID: meeting1.id }

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').content
    assert response_xml.at_xpath('/response/running').content
  end

  test 'responds with MissingMeetingIDError if meeting ID is not passed to isMeetingRunning' do
    get bigbluebutton_api_is_meeting_running_url

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with false if meeting is not found in database for isMeetingRunning' do
    get bigbluebutton_api_is_meeting_running_url, params: { meetingID: 'test' }

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal 'false', response_xml.at_xpath('/response/running').text
  end

  # getMeetings

  test 'responds with the correct meetings' do
    server1 = Server.create(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret', load: 1)
    server2 = Server.create(url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret', load: 1)

    stub_request(:get, encode_bbb_uri('getMeetings', server1.url, server1.secret))
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetings>' \
                       '<meeting>test-meeting-1<meeting></meetings></response>')
    stub_request(:get, encode_bbb_uri('getMeetings', server2.url, server2.secret))
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetings>' \
                       '<meeting>test-meeting-2<meeting></meetings></response>')

    get bigbluebutton_api_get_meetings_url

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert response_xml.xpath('//meeting[text()="test-meeting-1"]').present?
    assert response_xml.xpath('//meeting[text()="test-meeting-2"]').present?
  end

  test 'responds with noMeetings if there are no meetings on any server' do
    get bigbluebutton_api_get_meetings_url

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal 'noMeetings', response_xml.at_xpath('/response/messageKey').text
    assert_equal 'No meetings were found on this server.', response_xml.at_xpath('/response/message').text
  end

  # /create

  test 'responds with MissingMeetingIDError if meeting ID is not passed to create' do
    get bigbluebutton_api_create_url

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with InternalError if no servers are available in create' do
    get bigbluebutton_api_create_url, params: { meetingID: 'test-meeting-1' }

    response_xml = Nokogiri::XML(@response.body)

    expected_error = InternalError.new('Could not find any available servers.')

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'creates the room successfully' do
    server1 = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/',
                            secret: 'test-1-secret', enabled: true, load: 0)

    params = {
      meetingID: 'test-meeting-1',
    }

    stub_request(:get, encode_bbb_uri('create', server1.url, server1.secret, params))
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID>' \
      '<attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>')

    get bigbluebutton_api_create_url, params: params

    response_xml = Nokogiri::XML(@response.body)

    # Reload
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal params[:meetingID], meeting.id
    assert_equal server1.id, meeting.server.id
    assert_equal 1, server1.load
  end
end
