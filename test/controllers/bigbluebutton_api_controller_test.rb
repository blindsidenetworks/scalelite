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
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1')
    end

    url = 'https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=a4eee985e3f1f9524a6e2a32d1e35d3703e4cef9'

    stub_request(:get, url)
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>')

    get bigbluebutton_api_get_meeting_info_url, params: { meetingID: 'test-meeting-1' }

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').content
    assert_equal 'test-meeting-1', response_xml.at_xpath('/response/meetingID').content
  end

  test 'responds with MissingMeetingIDError if meeting ID is not passed' do
    get bigbluebutton_api_get_meeting_info_url

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

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
    assert_equal 'test-meeting-1', response_xml.search('meeting')[0].text
    assert_equal 'test-meeting-2', response_xml.search('meeting')[2].text
  end

  test 'responds with noMeetings if there are no meetings on any server' do
    get bigbluebutton_api_get_meetings_url

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal 'noMeetings', response_xml.at_xpath('/response/messageKey').text
    assert_equal 'No meetings were found on this server.', response_xml.at_xpath('/response/message').text
  end
end
