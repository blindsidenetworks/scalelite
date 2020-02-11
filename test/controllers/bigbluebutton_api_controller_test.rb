# frozen_string_literal: true

class BigBlueButtonApiControllerTest < ActionDispatch::IntegrationTest
  include BBBErrors
  include ApiHelper

  # /

  test 'responds with only success and version' do
    Rails.configuration.x.build_number = nil

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_url
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal '2.0', response_xml.at_xpath('/response/version').text
    assert_not response_xml.at_xpath('/response/build').present?

    assert_response :success
  end

  test 'includes build in response if env variable is set' do
    Rails.configuration.x.build_number = 'alpha-1'

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_url
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal '2.0', response_xml.at_xpath('/response/version').text
    assert_equal 'alpha-1', response_xml.at_xpath('/response/build').text

    assert_response :success
  end

  # getMeetingInfo

  test 'responds with the correct meeting info' do
    server = Server.create!(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1')
    Meeting.create!(id: 'test-meeting-1', server: server)

    url = 'https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=a4eee985e3f1f9524a6e2a32d1e35d3703e4cef9'

    stub_request(:get, url)
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>')

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_get_meeting_info_url, params: { meetingID: 'test-meeting-1' }
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').content
    assert_equal 'test-meeting-1', response_xml.at_xpath('/response/meetingID').content
  end

  test 'responds with MissingMeetingIDError if meeting ID is not passed' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_get_meeting_info_url
    end

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with MeetingNotFoundError if meeting is not found in database' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_get_meeting_info_url, params: { meetingID: 'test' }
    end

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

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_is_meeting_running_url, params: { meetingID: meeting1.id }
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').content
    assert response_xml.at_xpath('/response/running').content
  end

  test 'responds with MissingMeetingIDError if meeting ID is not passed to isMeetingRunning' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_is_meeting_running_url
    end

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with false if meeting is not found in database for isMeetingRunning' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_is_meeting_running_url, params: { meetingID: 'test' }
    end

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

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_get_meetings_url
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert response_xml.xpath('//meeting[text()="test-meeting-1"]').present?
    assert response_xml.xpath('//meeting[text()="test-meeting-2"]').present?
  end

  test 'responds with noMeetings if there are no meetings on any server' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_get_meetings_url
    end

    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal 'noMeetings', response_xml.at_xpath('/response/messageKey').text
    assert_equal 'No meetings were found on this server.', response_xml.at_xpath('/response/message').text
  end

  # /create

  test 'responds with MissingMeetingIDError if meeting ID is not passed to create' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_create_url
    end

    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with InternalError if no servers are available in create' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_create_url, params: { meetingID: 'test-meeting-1' }
    end

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

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_create_url, params: params
    end

    response_xml = Nokogiri::XML(@response.body)

    # Reload
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal params[:meetingID], meeting.id
    assert_equal server1.id, meeting.server.id
    assert_equal 1, server1.load
  end

  test 'creates the room successfully using POST' do
    server1 = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/',
                            secret: 'test-1-secret', enabled: true, load: 0)

    params = {
      meetingID: 'test-meeting-1',
    }

    stub_request(:get, encode_bbb_uri('create', server1.url, server1.secret, params))
      .to_return(body: '<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID>' \
      '<attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>')

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post bigbluebutton_api_create_url, params: params
    end

    response_xml = Nokogiri::XML(@response.body)

    # Reload
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal params[:meetingID], meeting.id
    assert_equal server1.id, meeting.server.id
    assert_equal 1, server1.load
  end

  # end

  test 'responds with MissingMeetingIDError if meeting ID is not passed to end' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_end_url
    end
    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with MeetingNotFoundError if meeting is not found in database for end' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_end_url, params: { meetingID: 'test-meeting-1' }
    end
    response_xml = Nokogiri::XML(@response.body)

    expected_error = MeetingNotFoundError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with MeetingNotFoundError if meetingID && password are passed but meeting doesnt exist' do
    server1 = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/',
                            secret: 'test-1-secret', enabled: true, load: 0)

    params = {
      meetingID: 'test-meeting-1',
      password: 'test-password',
    }

    stub_request(:get, encode_bbb_uri('end', server1.url, server1.secret, params))
      .to_return(body: '<response><returncode>FAILED</returncode><messageKey>notFound</messageKey>' \
        '<message>We could not find a meeting with that meeting ID - perhaps the meeting is not yet' \
        ' running?</message></response>')

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_end_url, params: params
    end
    response_xml = Nokogiri::XML(@response.body)

    expected_error = MeetingNotFoundError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with sentEndMeetingRequest if meeting exists and password is correct' do
    server1 = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/',
                            secret: 'test-1-secret', enabled: true, load: 0)
    Meeting.find_or_create_with_server('test-meeting-1', server1)

    params = {
      meetingID: 'test-meeting-1',
      password: 'test-password',
    }

    stub_request(:get, encode_bbb_uri('end', server1.url, server1.secret, params))
      .to_return(body: '<response><returncode>SUCCESS</returncode><messageKey>sentEndMeetingRequest</messageKey>' \
        '<message>A request to end the meeting was sent. Please wait a few seconds, and then use the getMeetingInfo' \
        ' or isMeetingRunning API calls to verify that it was ended.</message></response>')

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_end_url, params: params
    end
    response_xml = Nokogiri::XML(@response.body)

    assert_equal 'SUCCESS', response_xml.at_xpath('/response/returncode').text
    assert_equal 'sentEndMeetingRequest', response_xml.at_xpath('/response/messageKey').text
  end

  # join

  test 'responds with MissingMeetingIDError if meeting ID is not passed to join' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_join_url
    end
    response_xml = Nokogiri::XML(@response.body)

    expected_error = MissingMeetingIDError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'responds with MeetingNotFoundError if meeting is not found in database for join' do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_join_url, params: { meetingID: 'test-meeting-1' }
    end
    response_xml = Nokogiri::XML(@response.body)

    expected_error = MeetingNotFoundError.new

    assert_equal 'FAILED', response_xml.at_xpath('/response/returncode').text
    assert_equal expected_error.message_key, response_xml.at_xpath('/response/messageKey').text
    assert_equal expected_error.message, response_xml.at_xpath('/response/message').text
  end

  test 'redirects user to the corrent join url' do
    server1 = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/',
                            secret: 'test-1-secret', enabled: true, load: 0)
    meeting = Meeting.find_or_create_with_server('test-meeting-1', server1)

    params = { meetingID: meeting.id, password: 'test-password', fullName: 'test-name' }

    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get bigbluebutton_api_join_url, params: params
    end

    assert_redirected_to encode_bbb_uri('join', server1.url, server1.secret, params).to_s
  end

  # getRecordings

  test 'getRecordings with no parameters returns checksum error' do
    get bigbluebutton_api_get_recordings_url
    assert_response :success
    assert_select 'response>returncode', 'FAILED'
    assert_select 'response>messageKey', 'checksumError'
  end

  test 'getRecordings with invalid checksum returns checksum error' do
    get bigbluebutton_api_get_recordings_url, params: "checksum=#{'x' * 40}"
    assert_response :success
    assert_select 'response>returncode', 'FAILED'
    assert_select 'response>messageKey', 'checksumError'
  end

  test 'getRecordings with only checksum returns all recordings' do
    create_list(:recording, 3)

    params = encode_bbb_params('getRecordings', '')
    get bigbluebutton_api_get_recordings_url, params: params
    assert_response :success
    assert_select 'response>returncode', 'SUCCESS'
    assert_select 'response>recordings>recording', 3
  end

  test 'getRecordings fetches recording by meeting id' do
    r = create(:recording, :published, participants: 3)
    podcast = create(:playback_format, recording: r, format: 'podcast')
    presentation = create(:playback_format, recording: r, format: 'presentation')

    params = encode_bbb_params('getRecordings', { meetingID: r.meeting_id }.to_query)
    get bigbluebutton_api_get_recordings_url, params: params
    url_prefix = "#{@request.protocol}#{@request.host}"
    assert_response :success
    assert_select 'response>returncode', 'SUCCESS'
    assert_select 'response>recordings>recording', 1
    assert_select 'response>recordings>recording' do |rec_el|
      assert_select rec_el, 'recordID', r.record_id
      assert_select rec_el, 'meetingID', r.meeting_id
      assert_select rec_el, 'internalMeetingID', r.record_id
      assert_select rec_el, 'name', r.name
      assert_select rec_el, 'published', 'true'
      assert_select rec_el, 'state', 'published'
      assert_select rec_el, 'startTime', (r.starttime.to_r * 1000).to_i.to_s
      assert_select rec_el, 'endTime', (r.endtime.to_r * 1000).to_i.to_s
      assert_select rec_el, 'participants', '3'

      assert_select rec_el, 'playback>format', r.playback_formats.count
      assert_select rec_el, 'playback>format' do |format_els|
        format_els.each do |format_el|
          format_type = css_select(format_el, 'type')
          pf = nil
          case format_type.first.content
          when 'podcast' then pf = podcast
          when 'presentation' then pf = presentation
          else flunk("Unexpected playback format: #{format_type.first.content}")
          end

          assert_select format_el, 'type', pf.format
          assert_select format_el, 'url', "#{url_prefix}#{pf.url}"
          assert_select format_el, 'length', pf.length.to_s
          assert_select format_el, 'processingTime', pf.processing_time.to_s

          imgs = css_select(format_el, 'preview>images>image')
          assert_equal imgs.length, pf.thumbnails.count
          imgs.each_with_index do |img, i|
            t = thumbnails("fred_room_#{pf.format}_thumb#{i + 1}")
            assert_equal img['alt'], t.alt
            assert_equal img['height'], t.height.to_s
            assert_equal img['width'], t.width.to_s
            assert_equal img.content, "#{url_prefix}#{t.url}"
          end
        end
      end
    end
  end

  test 'getRecordings allows multiple comma-separated meeting IDs' do
    create_list(:recording, 5)
    r1 = create(:recording)
    r2 = create(:recording)

    params = encode_bbb_params('getRecordings', {
      meetingID: [r1.meeting_id, r2.meeting_id].join(','),
    }.to_query)
    get bigbluebutton_api_get_recordings_url, params: params

    assert_response :success
    assert_select 'response>returncode', 'SUCCESS'
    assert_select 'response>recordings>recording', 2
  end

  test 'getRecordings does case-sensitive match on recording id' do
    r = create(:recording)
    params = encode_bbb_params('getRecordings', { recordID: r.record_id.upcase }.to_query)
    get bigbluebutton_api_get_recordings_url, params: params
    assert_response :success
    assert_select 'response>returncode', 'SUCCESS'
    assert_select 'response>messageKey', 'noRecordings'
    assert_select 'response>recordings>recording', 0
  end

  test 'getRecordings does prefix match on recording id' do
    create_list(:recording, 5)
    r = create(:recording, meeting_id: 'bulk-prefix-match')
    create_list(:recording, 19, meeting_id: 'bulk-prefix-match')
    params = encode_bbb_params('getRecordings', { recordID: r.record_id[0, 40] }.to_query)
    get bigbluebutton_api_get_recordings_url, params: params
    assert_response :success
    assert_select 'response>returncode', 'SUCCESS'
    assert_select 'response>recordings>recording', 20
    assert_select 'recording>meetingID', r.meeting_id
  end

  test 'getRecordings allows multiple comma-separated recording IDs' do
    create_list(:recording, 5)
    r1 = create(:recording)
    r2 = create(:recording)

    params = encode_bbb_params('getRecordings', {
      recordID: [r1.record_id, r2.record_id].join(','),
    }.to_query)
    get bigbluebutton_api_get_recordings_url, params: params

    assert_response :success
    assert_select 'response>returncode', 'SUCCESS'
    assert_select 'response>recordings>recording', 2
  end
end
