# frozen_string_literal: true

class BigBlueButtonApiControllerTest < ActionDispatch::IntegrationTest
  include BBBErrors

  # /

  test 'responds with success and version' do
    get bigbluebutton_api_url

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal '2.0', response_xml.at_xpath('/response/version').text

    assert_response :success
  end

  # getMeetingInfo

  test 'responds with the correct meeting info if everything is setup correctly' do
    server = Server.create!(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1')
    Meeting.create!(id: 'test-meeting-1', server: server)

    url = 'https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=a4eee985e3f1f9524a6e2a32d1e35d3703e4cef9'

    stub_request(:get, url)
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>')

    get bigbluebutton_api_getMeetingInfo_url, params: { meetingID: 'test-meeting-1' }

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').content
    assert_equal 'test-meeting-1', response_xml.at_xpath('/response/meetingID').content
  end

  test 'responds with MissingMeetingIDError if meeting ID is not passed' do
    get bigbluebutton_api_getMeetingInfo_url

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with MeetingNotFoundError if meeting is not found in database' do
    get bigbluebutton_api_getMeetingInfo_url, params: { meetingID: 'test' }

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MeetingNotFoundError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end
end
