class BigBlueButtonApiControllerTest < ActionDispatch::IntegrationTest
  include(BBBErrors)
  include(ApiHelper)
  
	it("index responds with only success and version for a get request") do
    Rails.configuration.x.build_number = nil
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/version").text).to(eq("2.0"))
    assert_not(response_xml.at_xpath("/response/build").present?)
    assert_response(:success)
  end
	
	it("index responds with only success and version for a post request") do
    Rails.configuration.x.build_number = nil
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/version").text).to(eq("2.0"))
    assert_not(response_xml.at_xpath("/response/build").present?)
    assert_response(:success)
  end
  
	it("index includes build in response if env variable is set") do
    Rails.configuration.x.build_number = "alpha-1"
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/version").text).to(eq("2.0"))
    expect(response_xml.at_xpath("/response/build").text).to(eq("alpha-1"))
    assert_response(:success)
  end
  
	it("getMeetingInfo responds with the correct meeting info for a post request") do
    server = Server.create!(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1")
    Meeting.create!(:id => "test-meeting-1", :server => server)
    url = "https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=7901d9cf0f7e63a7e5eacabfd75fabfb223259d6c045ac5b4d86fb774c371945"
    stub_request(:get, url).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_get_meeting_info_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/meetingID").content).to(eq("test-meeting-1"))
  end
  
	it("getMeetingInfo responds with the correct meeting info for a post request with checksum value computed using SHA1") do
    server = Server.create!(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1")
    Meeting.create!(:id => "SHA1_meeting", :server => server)
    url = "https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=SHA1_meeting&checksum=c8cd32fbbc006424c5784b8e9679b8ff0d21c577d361d9afdab37638b1d7a4e8"
    stub_request(:get, url).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>SHA1_meeting</meetingID></response>")
    Rails.configuration.x.stub(:loadbalancer_secrets, ["test-2"]) do
      post(bigbluebutton_api_get_meeting_info_url, :params => ({ :meetingID => "SHA1_meeting", :checksum => "cbf00ea96fae6ff06c2cb311bbde8b26ad66d765" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/meetingID").content).to(eq("SHA1_meeting"))
  end
  
	it("getMeetingInfo responds with the correct meeting info for a post request with checksum value computed using SHA256") do
    server = Server.create!(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1")
    Meeting.create!(:id => "SHA256_meeting", :server => server)
    url = "https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=SHA256_meeting&checksum=cd288062f4b623e1f975150e4c47a8cc212937174acafe8b1f340d5aef1877af"
    stub_request(:get, url).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>SHA256_meeting</meetingID></response>")
    Rails.configuration.x.stub(:loadbalancer_secrets, ["test-1"]) do
      post(bigbluebutton_api_get_meeting_info_url, :params => ({ :meetingID => "SHA256_meeting", :checksum => "217da05b692320353e17a1b11c24e9e715caeee51ab5af35231ee5becc350d1e" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/meetingID").content).to(eq("SHA256_meeting"))
  end
  
	it("getMeetingInfo responds with the correct meeting info for a get request") do
    server = Server.create!(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1")
    Meeting.create!(:id => "test-meeting-1", :server => server)
    url = "https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=7901d9cf0f7e63a7e5eacabfd75fabfb223259d6c045ac5b4d86fb774c371945"
    stub_request(:get, url).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meeting_info_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/meetingID").content).to(eq("test-meeting-1"))
  end
  
	it("getMeetingInfo responds with appropriate error on timeout") do
    server = Server.create!(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1")
    Meeting.create!(:id => "test-meeting-1", :server => server)
    url = "https://test-1.example.com/bigbluebutton/api/getMeetingInfo?meetingID=test-meeting-1&checksum=7901d9cf0f7e63a7e5eacabfd75fabfb223259d6c045ac5b4d86fb774c371945"
    stub_request(:get, url).to_timeout
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meeting_info_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
    expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to access meeting on server."))
  end
  
	it("getMeetingInfo responds with MissingMeetingIDError if meeting ID is not passed") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meeting_info_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MissingMeetingIDError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("getMeetingInfo responds with MeetingNotFoundError if meeting is not found in database") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meeting_info_url, :params => ({ :meetingID => "test" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MeetingNotFoundError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("isMeetingRunning responds with the correct meeting status for a get request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 0)
    meeting1 = Meeting.find_or_create_with_server("Demo Meeting", server1, "mp")
    stub_request(:get, encode_bbb_uri("isMeetingRunning", server1.url, server1.secret, "meetingID" => meeting1.id)).to_return(:body => "<response><returncode>SUCCESS</returncode><running>true</running></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_is_meeting_running_url, :params => ({ :meetingID => meeting1.id }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/running").content).to(be_truthy)
  end
  
	it("isMeetingRunning responds with the correct meeting status for a post request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 0)
    meeting1 = Meeting.find_or_create_with_server("Demo Meeting", server1, "mp")
    stub_request(:get, encode_bbb_uri("isMeetingRunning", server1.url, server1.secret, "meetingID" => meeting1.id)).to_return(:body => "<response><returncode>SUCCESS</returncode><running>true</running></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_is_meeting_running_url, :params => ({ :meetingID => meeting1.id }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/running").content).to(be_truthy)
  end
  
	it("isMeetingRunning responds with appropriate error on timeout") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 0)
    meeting1 = Meeting.find_or_create_with_server("Demo Meeting", server1, "mp")
    stub_request(:get, encode_bbb_uri("isMeetingRunning", server1.url, server1.secret, "meetingID" => meeting1.id)).to_timeout
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_is_meeting_running_url, :params => ({ :meetingID => meeting1.id }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
    expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to access meeting on server."))
  end
  
	it("isMeetingRunning responds with MissingMeetingIDError if meeting ID is not passed to isMeetingRunning") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_is_meeting_running_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MissingMeetingIDError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("isMeetingRunning responds with false if meeting is not found in database for isMeetingRunning") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_is_meeting_running_url, :params => ({ :meetingID => "test" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/running").text).to(eq("false"))
  end
  
	it("getMeetings responds with the correct meetings  for a get request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 1, :online => true, :enabled => true)
    server2 = Server.create(:url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :load => 1, :online => true, :enabled => true)
    stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
    stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meetings_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]").present?).to(eq(true))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]").present?).to(eq(true))
  end
  
	it("getMeetings responds with the correct meetings for a post request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 1, :online => true, :enabled => true)
    server2 = Server.create(:url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :load => 1, :online => true, :enabled => true)
    stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
    stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_get_meetings_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]").present?).to(eq(true))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]").present?).to(eq(true))
  end
  
	it("getMeetings responds with appropriate error on timeout") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 1, :online => true, :enabled => true)
    server2 = Server.create(:url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :load => 1, :online => true, :enabled => true)
    server3 = Server.create(:url => "https://test-3.example.com/bigbluebutton/api", :secret => "test-3-secret", :load => 1, :online => true, :enabled => true)
    stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
    stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret)).to_timeout
    stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3<meeting></meetings></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meetings_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
    expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to access server."))
  end
  
	it("getMeetings responds with noMeetings if there are no meetings on any server") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meetings_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq("noMeetings"))
    expect(response_xml.at_xpath("/response/message").text).to(eq("no meetings were found on this server"))
    expect(response_xml.at_xpath("/response/meetings").text).to(eq(""))
  end
  
	it("getMeetings only makes a request to online and enabled servers") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 1, :online => true, :enabled => true)
    server2 = Server.create(:url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :load => 1, :online => true, :enabled => true)
    server3 = Server.create(:url => "https://test-3.example.com/bigbluebutton/api", :secret => "test-2-secret", :load => 1, :online => false, :enabled => true)
    stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
    stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
    stub_request(:get, encode_bbb_uri("getMeetings", server3.url, server3.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-3<meeting></meetings></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meetings_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]").present?).to(eq(true))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]").present?).to(eq(true))
    assert_not(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]").present?)
  end
  
	it("getMeetings only makes a request to online and servers in state cordoned/enabled") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api", :secret => "test-1-secret", :load => 1, :online => true, :state => "cordoned")
    server2 = Server.create(:url => "https://test-2.example.com/bigbluebutton/api", :secret => "test-2-secret", :load => 1, :online => true, :state => "enabled")
    Server.create(:url => "https://test-3.example.com/bigbluebutton/api", :secret => "test-3-secret", :load => 1, :online => false)
    Server.create(:url => "https://test-4.example.com/bigbluebutton/api", :secret => "test-4-secret", :load => 1, :online => true, :state => "disabled")
    stub_request(:get, encode_bbb_uri("getMeetings", server1.url, server1.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-1<meeting></meetings></response>")
    stub_request(:get, encode_bbb_uri("getMeetings", server2.url, server2.secret)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetings><meeting>test-meeting-2<meeting></meetings></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_get_meetings_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-1\"]").present?).to(eq(true))
    expect(response_xml.xpath("//meeting[text()=\"test-meeting-2\"]").present?).to(eq(true))
    assert_not(response_xml.xpath("//meeting[text()=\"test-meeting-3\"]").present?)
  end
  
	it("create responds with MissingMeetingIDError if meeting ID is not passed to create") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_create_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MissingMeetingIDError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("create responds with InternalError if no servers are available in create") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_create_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = InternalError.new("Could not find any available servers.")
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("create creates the room successfully for a get request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :moderatorPW => "mp" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_create_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(meeting.id).to(eq(params[:meetingID]))
    expect(meeting.server.id).to(eq(server1.id))
    expect(server1.load).to(eq(1))
  end
  
	it("create creates the room successfully for a post request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :moderatorPW => "mp" }
    stub_request(:post, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_create_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(meeting.id).to(eq(params[:meetingID]))
    expect(meeting.server.id).to(eq(server1.id))
    expect(server1.load).to(eq(1))
  end
  
	it("create returns an appropriate error on timeout") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :moderatorPW => "mp" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_timeout
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_create_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").content).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").content).to(eq("internalError"))
    expect(response_xml.at_xpath("/response/message").content).to(eq("Unable to create meeting on server."))
  end
  
	it("create increments the server load by the value of load_multiplier") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0, :load_multiplier => 7.0)
    params = { :meetingID => "test-meeting-1", :moderatorPW => "mp" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_create_url, :params => params)
    end
    server1 = Server.find(server1.id)
    expect(server1.load).to(eq(7))
  end
  
	it("create creates the room successfully using POST") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :moderatorPW => "mp" }
    stub_request(:post, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_create_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(meeting.id).to(eq(params[:meetingID]))
    expect(meeting.server.id).to(eq(server1.id))
    expect(server1.load).to(eq(1))
  end
  
	it("create sets the duration param to MAX_MEETING_DURATION if set") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    create_params = { :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    params = { :meetingID => "test-meeting-1", :moderatorPW => "test-password", :duration => 3600 }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    Rails.configuration.x.stub(:max_meeting_duration, 3600) do
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_create_url, :params => create_params)
      end
      response_xml = Nokogiri.XML(@response.body)
      expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    end
  end
  
	it("create sets the duration param to MAX_MEETING_DURATION if passed duration is greater than MAX_MEETING_DURATION") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    create_params = { :duration => 5000, :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    params = { :duration => 3600, :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    Rails.configuration.x.stub(:max_meeting_duration, 3600) do
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_create_url, :params => create_params)
      end
      response_xml = Nokogiri.XML(@response.body)
      expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    end
  end
  
	it("create sets the duration param to MAX_MEETING_DURATION if passed duration is 0") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    create_params = { :duration => 0, :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    params = { :duration => 3600, :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    Rails.configuration.x.stub(:max_meeting_duration, 3600) do
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_create_url, :params => create_params)
      end
      response_xml = Nokogiri.XML(@response.body)
      expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    end
  end
  
	it("create does not set the duration param to MAX_MEETING_DURATION if passed duration is less than MAX_MEETING_DURATION") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    create_params = { :duration => 1200, :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    params = { :duration => 1200, :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    Rails.configuration.x.stub(:max_meeting_duration, 3600) do
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_create_url, :params => create_params)
      end
      response_xml = Nokogiri.XML(@response.body)
      expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    end
  end
  
	it("create creates the room successfully  with only permitted params for create") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :test4 => "", :test2 => "", :moderatorPW => "test-password" }
    filtered_params = { :meetingID => "test-meeting-1", :moderatorPW => "test-password" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, filtered_params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    mocked_method = MiniTest::Mock.new
    return_value = { "meetingID" => "test-meeting-1" }
    Rails.configuration.x.stub(:create_exclude_params, ["test4", "test2"]) do
      mocked_method.expect(:pass_through_params, return_value, [Rails.configuration.x.create_exclude_params])
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_create_url, :params => params)
      end
      mocked_method.pass_through_params(["test4", "test2"])
      mocked_method.verify
    end
    response_xml = Nokogiri.XML(@response.body)
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(meeting.id).to(eq(params[:meetingID]))
    expect(meeting.server.id).to(eq(server1.id))
    expect(server1.load).to(eq(1))
  end
  
	it("create creates the room successfully with given params if excluded params list is empty") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :test4 => "", :test2 => "", :moderatorPW => "test-password" }
    filtered_params = { :meetingID => "test-meeting-1", :test4 => "", :test2 => "", :moderatorPW => "test-password" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, filtered_params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    mocked_method = MiniTest::Mock.new
    return_value = { :meetingID => "test-meeting-1", :test4 => "", :test2 => "" }
    Rails.configuration.x.stub(:create_exclude_params, []) do
      mocked_method.expect(:pass_through_params, return_value, [Rails.configuration.x.create_exclude_params])
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_create_url, :params => params)
      end
      mocked_method.pass_through_params([])
      mocked_method.verify
    end
    response_xml = Nokogiri.XML(@response.body)
    server1 = Server.find(server1.id)
    meeting = Meeting.find(params[:meetingID])
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(meeting.id).to(eq(params[:meetingID]))
    expect(meeting.server.id).to(eq(server1.id))
    expect(server1.load).to(eq(1))
  end
  
	it("create creates a record in callback_data if  params[\"meta_bn-recording-ready-url\"] is present in request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :test4 => "", :test2 => "", :moderatorPW => "test-password", "meta_bn-recording-ready-url" => "https://test-1.example.com/bigbluebutton/api/" }
    bbb_params = { :meetingID => "test-meeting-1", :test4 => "", :test2 => "", :moderatorPW => "test-password" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, bbb_params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_create_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    callback_data = CallbackData.find_by(:meeting_id => params[:meetingID])
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(:recording_ready_url => "https://test-1.example.com/bigbluebutton/api/").to(eq(callback_data.callback_attributes))
  end
  
	it("create creates a record in callback_data if  params[\"meta_analytics-callback-url\"] is present in request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-66", :test4 => "", :test2 => "", :moderatorPW => "test-password", "meta_analytics-callback-url" => "https://test.scalelite.com/bigbluebutton/api/analytics_callback" }
    Rails.configuration.x.stub(:url_host, "test.scalelite.com") do
      stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_create_url, :params => params)
      end
    end
    response_xml = Nokogiri.XML(@response.body)
    callback_data = CallbackData.find_by(:meeting_id => params[:meetingID])
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(:analytics_callback_url => "https://test.scalelite.com/bigbluebutton/api/analytics_callback").to(eq(callback_data.callback_attributes))
  end
  
	it("analytics_callback makes a callback to the specific meetings analytics_callback_url stored in\n        callback_attributes table") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1111", :test4 => "", :test2 => "", :moderatorPW => "test-password", "meta_analytics-callback-url" => "https://test.scalelite.com/bigbluebutton/api/analytics_callback" }
    stub_request(:get, encode_bbb_uri("create", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><meetingID>test-meeting-1</meetingID><attendeePW>ap</attendeePW><moderatorPW>mp</moderatorPW><messageKey/><message/></response>")
    stub_request(:post, "https://test.scalelite.com/bigbluebutton/api/analytics_callback").to_return(:status => :ok, :body => "", :headers => ({}))
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      Rails.configuration.x.stub(:url_host, "test.scalelite.com") do
        get(bigbluebutton_api_create_url, :params => params)
        post(bigbluebutton_api_analytics_callback_url, :params => ({ :meeting_id => "test-meeting-1111" }))
      end
    end
    callback_data = CallbackData.find_by(:meeting_id => params[:meetingID])
    expect(@response.status).to(eq(204))
    expect(:analytics_callback_url => "https://test.scalelite.com/bigbluebutton/api/analytics_callback").to(eq(callback_data.callback_attributes))
  end
  
	it("end responds with MissingMeetingIDError if meeting ID is not passed to end") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_end_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MissingMeetingIDError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("end responds with MeetingNotFoundError if meeting is not found in database for end") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_end_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MeetingNotFoundError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("end responds with MeetingNotFoundError if meetingID && password are passed but meeting doesnt exist") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    params = { :meetingID => "test-meeting-1", :password => "test-password" }
    stub_request(:get, encode_bbb_uri("end", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>FAILED</returncode><messageKey>notFound</messageKey><message>We could not find a meeting with that meeting ID - perhaps the meeting is not yet running?</message></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_end_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MeetingNotFoundError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("end responds with sentEndMeetingRequest if meeting exists and password is correct for a get request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    params = { :meetingID => "test-meeting-1", :password => "test-password" }
    stub_request(:get, encode_bbb_uri("end", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><messageKey>sentEndMeetingRequest</messageKey><message>A request to end the meeting was sent. Please wait a few seconds, and then use the getMeetingInfo or isMeetingRunning API calls to verify that it was ended.</message></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_end_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq("sentEndMeetingRequest"))
    expect { Meeting.find("test-meeting-1") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  
	it("end responds with sentEndMeetingRequest if meeting exists and password is correct for a post request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    params = { :meetingID => "test-meeting-1", :password => "test-password" }
    stub_request(:get, encode_bbb_uri("end", server1.url, server1.secret, params)).to_return(:body => "<response><returncode>SUCCESS</returncode><messageKey>sentEndMeetingRequest</messageKey><message>A request to end the meeting was sent. Please wait a few seconds, and then use the getMeetingInfo or isMeetingRunning API calls to verify that it was ended.</message></response>")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_end_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("SUCCESS"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq("sentEndMeetingRequest"))
    expect { Meeting.find("test-meeting-1") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  
	it("end returns error on timeout but still deletes meeting") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0)
    Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    params = { :meetingID => "test-meeting-1", :password => "test-password" }
    stub_request(:get, encode_bbb_uri("end", server1.url, server1.secret, params)).to_timeout
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_end_url, :params => params)
    end
    response_xml = Nokogiri.XML(@response.body)
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq("internalError"))
    expect(response_xml.at_xpath("/response/message").text).to(eq("Unable to access meeting on server."))
    expect { Meeting.find("test-meeting-1") }.to(raise_error(ApplicationRedisRecord::RecordNotFound))
  end
  
	it("join responds with MissingMeetingIDError if meeting ID is not passed to join") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_join_url)
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MissingMeetingIDError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("join responds with MeetingNotFoundError if meeting is not found in database for join") do
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_join_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = MeetingNotFoundError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("join redirects user to the corrent join url for a get request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0, :online => true)
    meeting = Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    params = { :meetingID => meeting.id, :password => "test-password", :fullName => "test-name" }
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_join_url, :params => params)
    end
    assert_redirected_to(encode_bbb_uri("join", server1.url, server1.secret, params).to_s)
  end
  
	it("join redirects user to the corrent join url for a post request") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0, :online => true)
    meeting = Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    params = { :meetingID => meeting.id, :password => "test-password", :fullName => "test-name" }
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_join_url, :params => params)
    end
    assert_redirected_to(encode_bbb_uri("join", server1.url, server1.secret, params).to_s)
  end
  
	it("join redirects user to the current join url with only permitted params for join") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0, :online => true)
    meeting = Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    params = { :meetingID => meeting.id, :password => "test-password", :fullName => "test-name", :test1 => "", :test2 => "" }
    Rails.configuration.x.stub(:join_exclude_params, ["test1", "test2"]) do
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_join_url, :params => params)
      end
      filtered_params = { :meetingID => meeting.id, :password => "test-password", :fullName => "test-name" }
      assert_redirected_to(encode_bbb_uri("join", server1.url, server1.secret, filtered_params).to_s)
    end
  end
  
	it("join redirects user to the current join url with given params if excluded params list is empty") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => true, :load => 0, :online => true)
    meeting = Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    params = { :meetingID => meeting.id, :password => "test-password", :fullName => "test-name", :test1 => "", :test2 => "" }
    Rails.configuration.x.stub(:join_exclude_params, []) do
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        get(bigbluebutton_api_join_url, :params => params)
      end
      assert_redirected_to(encode_bbb_uri("join", server1.url, server1.secret, params).to_s)
    end
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_join_url, :params => params)
    end
    filtered_params = { :meetingID => meeting.id, :password => "test-password", :fullName => "test-name" }
    expect(["test1", "test2"]).to(eq(Rails.configuration.x.join_exclude_params))
    assert_redirected_to(encode_bbb_uri("join", server1.url, server1.secret, filtered_params).to_s)
  end
  
	it("join responds with ServerUnavailableError if server is disabled") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :enabled => false, :load => 0, :online => true)
    Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_join_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = ServerUnavailableError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("join responds with ServerUnavailableError if server is offline") do
    server1 = Server.create(:url => "https://test-1.example.com/bigbluebutton/api/", :secret => "test-1-secret", :load => 0, :online => false, :enabled => true)
    Meeting.find_or_create_with_server("test-meeting-1", server1, "mp")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      get(bigbluebutton_api_join_url, :params => ({ :meetingID => "test-meeting-1" }))
    end
    response_xml = Nokogiri.XML(@response.body)
    expected_error = ServerUnavailableError.new
    expect(response_xml.at_xpath("/response/returncode").text).to(eq("FAILED"))
    expect(response_xml.at_xpath("/response/messageKey").text).to(eq(expected_error.message_key))
    expect(response_xml.at_xpath("/response/message").text).to(eq(expected_error.message))
  end
  
	it("getRecordings with no parameters returns checksum error") do
    get(bigbluebutton_api_get_recordings_url)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("getRecordings with invalid checksum returns checksum error") do
    get(bigbluebutton_api_get_recordings_url, :params => ("checksum=#{("x" * 40)}"))
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("getRecordings with only checksum returns all recordings for a get request") do
    create_list(:recording, 3, :state => "published")
    params = encode_bbb_params("getRecordings", "")
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 3)
  end
  
	it("getRecordings with get_recordings_api_filtered does not return any recordings and returns error response\n        if no meetingId/recordId is provided") do
    create_list(:recording, 3, :state => "published")
    params = encode_bbb_params("getRecordings", "")
    Rails.configuration.x.stub(:get_recordings_api_filtered, true) do
      get(bigbluebutton_api_get_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "missingParameters")
    assert_select("response>message", "param meetingID or recordID must be included.")
  end
  
	it("getRecordings with only checksum returns all recordings for a post request") do
    create_list(:recording, 3, :state => "published")
    params = encode_bbb_params("getRecordings", "")
    post(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 3)
  end
  
	it("getRecordings fetches recording by meeting id") do
    r = create(:recording, :published, :participants => 3, :state => "published")
    podcast = create(:playback_format, :recording => r, :format => "podcast")
    presentation = create(:playback_format, :recording => r, :format => "presentation")
    params = encode_bbb_params("getRecordings", { :meetingID => r.meeting_id }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    url_prefix = "#{@request.protocol}#{@request.host}"
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 1)
    assert_select("response>recordings>recording") do |rec_el|
      assert_select(rec_el, "recordID", r.record_id)
      assert_select(rec_el, "meetingID", r.meeting_id)
      assert_select(rec_el, "internalMeetingID", r.record_id)
      assert_select(rec_el, "name", r.name)
      assert_select(rec_el, "published", "true")
      assert_select(rec_el, "state", "published")
      assert_select(rec_el, "startTime", (r.starttime.to_r * 1000).to_i.to_s)
      assert_select(rec_el, "endTime", (r.endtime.to_r * 1000).to_i.to_s)
      assert_select(rec_el, "participants", "3")
      assert_select(rec_el, "playback>format", r.playback_formats.count)
      assert_select(rec_el, "playback>format") do |format_els|
        format_els.each do |format_el|
          format_type = css_select(format_el, "type")
          pf = nil
          case format_type.first.content
          when "podcast" then
            pf = podcast
          when "presentation" then
            pf = presentation
          else
            flunk("Unexpected playback format: #{format_type.first.content}")
          end
          assert_select(format_el, "type", pf.format)
          assert_select(format_el, "url", "#{url_prefix}#{pf.url}")
          assert_select(format_el, "length", pf.length.to_s)
          assert_select(format_el, "processingTime", pf.processing_time.to_s)
          imgs = css_select(format_el, "preview>images>image")
          expect(pf.thumbnails.count).to(eq(imgs.length))
          imgs.each_with_index do |img, i|
            t = thumbnails("fred_room_#{pf.format}_thumb#{(i + 1)}")
            expect(t.alt).to(eq(img["alt"]))
            expect(t.height.to_s).to(eq(img["height"]))
            expect(t.width.to_s).to(eq(img["width"]))
            expect("#{url_prefix}#{t.url}").to(eq(img.content))
          end
        end
      end
    end
  end
  
	it("getRecordings with get_recordings_api_filtered fetches recording by meeting id") do
    r = create(:recording, :published, :participants => 3, :state => "published")
    podcast = create(:playback_format, :recording => r, :format => "podcast")
    presentation = create(:playback_format, :recording => r, :format => "presentation")
    params = encode_bbb_params("getRecordings", { :meetingID => r.meeting_id }.to_query)
    Rails.configuration.x.stub(:get_recordings_api_filtered, true) do
      get(bigbluebutton_api_get_recordings_url, :params => params)
    end
    url_prefix = "#{@request.protocol}#{@request.host}"
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 1)
    assert_select("response>recordings>recording") do |rec_el|
      assert_select(rec_el, "recordID", r.record_id)
      assert_select(rec_el, "meetingID", r.meeting_id)
      assert_select(rec_el, "internalMeetingID", r.record_id)
      assert_select(rec_el, "name", r.name)
      assert_select(rec_el, "published", "true")
      assert_select(rec_el, "state", "published")
      assert_select(rec_el, "startTime", (r.starttime.to_r * 1000).to_i.to_s)
      assert_select(rec_el, "endTime", (r.endtime.to_r * 1000).to_i.to_s)
      assert_select(rec_el, "participants", "3")
      assert_select(rec_el, "playback>format", r.playback_formats.count)
      assert_select(rec_el, "playback>format") do |format_els|
        format_els.each do |format_el|
          format_type = css_select(format_el, "type")
          pf = nil
          case format_type.first.content
          when "podcast" then
            pf = podcast
          when "presentation" then
            pf = presentation
          else
            flunk("Unexpected playback format: #{format_type.first.content}")
          end
          assert_select(format_el, "type", pf.format)
          assert_select(format_el, "url", "#{url_prefix}#{pf.url}")
          assert_select(format_el, "length", pf.length.to_s)
          assert_select(format_el, "processingTime", pf.processing_time.to_s)
          imgs = css_select(format_el, "preview>images>image")
          expect(pf.thumbnails.count).to(eq(imgs.length))
          imgs.each_with_index do |img, i|
            t = thumbnails("fred_room_#{pf.format}_thumb#{(i + 1)}")
            expect(t.alt).to(eq(img["alt"]))
            expect(t.height.to_s).to(eq(img["height"]))
            expect(t.width.to_s).to(eq(img["width"]))
            expect("#{url_prefix}#{t.url}").to(eq(img.content))
          end
        end
      end
    end
  end
  
	it("getRecordings allows multiple comma-separated meeting IDs") do
    create_list(:recording, 5, :state => "published")
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "published")
    params = encode_bbb_params("getRecordings", { :meetingID => [r1.meeting_id, r2.meeting_id].join(",") }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 2)
  end
  
	it("getRecordings with get_recordings_api_filtered allows multiple comma-separated meeting IDs") do
    create_list(:recording, 5, :state => "published")
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "published")
    params = encode_bbb_params("getRecordings", { :meetingID => [r1.meeting_id, r2.meeting_id].join(",") }.to_query)
    Rails.configuration.x.stub(:get_recordings_api_filtered, true) do
      get(bigbluebutton_api_get_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 2)
  end
  
	it("getRecordings does case-sensitive match on recording id") do
    r = create(:recording, :state => "published")
    params = encode_bbb_params("getRecordings", { :recordID => r.record_id.upcase }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>messageKey", "noRecordings")
    assert_select("response>recordings>recording", 0)
  end
  
	it("getRecordings does prefix match on recording id") do
    create_list(:recording, 5, :state => "published")
    r = create(:recording, :meeting_id => "bulk-prefix-match", :state => "published")
    create_list(:recording, 19, :meeting_id => "bulk-prefix-match", :state => "published")
    params = encode_bbb_params("getRecordings", { :recordID => r.record_id[0, 40] }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 20)
    assert_select("recording>meetingID", r.meeting_id)
  end
  
	it("getRecordings allows multiple comma-separated recording IDs") do
    create_list(:recording, 5, :state => "published")
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "published")
    params = encode_bbb_params("getRecordings", { :recordID => [r1.record_id, r2.record_id].join(",") }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 2)
  end
  
	it("getRecordings with get_recordings_api_filtered allows multiple comma-separated recording IDs") do
    create_list(:recording, 5, :state => "published")
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "published")
    params = encode_bbb_params("getRecordings", { :recordID => [r1.record_id, r2.record_id].join(",") }.to_query)
    Rails.configuration.x.stub(:get_recordings_api_filtered, true) do
      get(bigbluebutton_api_get_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 2)
  end
  
	it("getRecordings filter based on recording states") do
    create_list(:recording, 5)
    r1 = create(:recording, :state => "processing")
    r2 = create(:recording, :state => "unpublished")
    r3 = create(:recording, :state => "deleted")
    params = encode_bbb_params("getRecordings", { :recordID => [r1.record_id, r2.record_id, r3.record_id].join(","), :state => ["published", "unpublished"].join(",") }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 1)
  end
  
	it("getRecordings with get_recordings_api_filtered filters based on recording states") do
    create_list(:recording, 5, :state => "deleted")
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "unpublished")
    r3 = create(:recording, :state => "deleted")
    params = encode_bbb_params("getRecordings", { :recordID => [r1.record_id, r2.record_id, r3.record_id].join(","), :state => ["published", "unpublished"].join(",") }.to_query)
    Rails.configuration.x.stub(:get_recordings_api_filtered, true) do
      get(bigbluebutton_api_get_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 2)
  end
  
	it("getRecordings filter based on recording states and meta_params") do
    create_list(:recording, 5, :state => "processing")
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "unpublished")
    r3 = create(:recording, :state => "deleted")
    create(:metadatum, :recording => r1, :key => "bbb-context-name", :value => "test1")
    create(:metadatum, :recording => r3, :key => "bbb-origin-tag", :value => "GL")
    create(:metadatum, :recording => r2, :key => "bbb-origin-tag", :value => "GL")
    params = encode_bbb_params("getRecordings", { :recordID => [r1.record_id, r2.record_id, r3.record_id].join(","), :state => ["published", "unpublished", "deleted"].join(","), :"meta_bbb-context-name" => ["test1", "test2"].join(","), :"meta_bbb-origin-tag" => ["GL"].join(",") }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 3)
  end
  
	it("getRecordings with get_recordings_api_filtered filters based on recording states and meta_params") do
    create_list(:recording, 5)
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "unpublished")
    r3 = create(:recording)
    create(:metadatum, :recording => r1, :key => "bbb-context-name", :value => "test1")
    create(:metadatum, :recording => r3, :key => "bbb-origin-tag", :value => "GL")
    create(:metadatum, :recording => r2, :key => "bbb-origin-tag", :value => "GL")
    params = encode_bbb_params("getRecordings", { :recordID => [r1.record_id, r2.record_id, r3.record_id].join(","), :state => ["published", "unpublished"].join(","), :"meta_bbb-context-name" => ["test1", "test2"].join(","), :"meta_bbb-origin-tag" => ["GL"].join(",") }.to_query)
    Rails.configuration.x.stub(:get_recordings_api_filtered, true) do
      get(bigbluebutton_api_get_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 2)
  end
  
	it("getRecordings filter based on recording states and meta_params and\n       returns no recordings if no match found") do
    create_list(:recording, 5)
    r1 = create(:recording, :state => "published")
    r2 = create(:recording, :state => "unpublished")
    r3 = create(:recording)
    create(:metadatum, :recording => r1, :key => "bbb-context-name", :value => "test12")
    create(:metadatum, :recording => r3, :key => "bbb-origin-tag", :value => "GL1")
    create(:metadatum, :recording => r2, :key => "bbb-origin-tag", :value => "GL2")
    params = encode_bbb_params("getRecordings", { :recordID => [r1.record_id, r2.record_id, r3.record_id].join(","), :state => ["published", "unpublished"].join(","), :"meta_bbb-context-name" => ["test1", "test2"].join(","), :"meta_bbb-origin-tag" => ["GL"].join(",") }.to_query)
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>recordings>recording", 0)
  end
  
	it("publishRecordings with no parameters returns checksum error") do
    get(bigbluebutton_api_publish_recordings_url)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("publishRecordings with invalid checksum returns checksum error") do
    get(bigbluebutton_api_publish_recordings_url, :params => ("checksum=#{("x" * 40)}"))
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("publishRecordings requires recordID parameter") do
    params = encode_bbb_params("publishRecordings", { :publish => "true" }.to_query)
    get(bigbluebutton_api_publish_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "missingParamRecordID")
  end
  
	it("publishRecordings requires publish parameter") do
    r = create(:recording)
    params = encode_bbb_params("publishRecordings", { :recordID => r.record_id }.to_query)
    get(bigbluebutton_api_publish_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "missingParamPublish")
  end
  
	it("publishRecordings updates published property to false") do
    r = create(:recording, :published)
    expect(true).to(eq(r.published))
    params = encode_bbb_params("publishRecordings", { :recordID => r.record_id, :publish => "false" }.to_query)
    get(bigbluebutton_api_publish_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>published", "false")
    r.reload
    expect(false).to(eq(r.published))
  end
  
	it("publishRecordings updates published property to true for a get request") do
    r = create(:recording, :unpublished)
    expect(false).to(eq(r.published))
    params = encode_bbb_params("publishRecordings", { :recordID => r.record_id, :publish => "true" }.to_query)
    get(bigbluebutton_api_publish_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>published", "true")
    r.reload
    expect(true).to(eq(r.published))
  end
  
	it("publishRecordings updates published property to true for a post request") do
    r = create(:recording, :unpublished)
    expect(false).to(eq(r.published))
    params = encode_bbb_params("publishRecordings", { :recordID => r.record_id, :publish => "true" }.to_query)
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_publish_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>published", "true")
    r.reload
    expect(true).to(eq(r.published))
  end
  
	it("publishRecordings returns error if no recording found") do
    create(:recording)
    params = encode_bbb_params("publishRecordings", { :recordID => "not-a-real-record-id", :publish => "true" }.to_query)
    get(bigbluebutton_api_publish_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
  end
  
	it("updateRecordings with no parameters returns checksum error") do
    get(bigbluebutton_api_update_recordings_url)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("updateRecordings with invalid checksum returns checksum error") do
    get(bigbluebutton_api_update_recordings_url, :params => ("checksum=#{("x" * 40)}"))
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("updateRecordings requires recordID parameter") do
    params = encode_bbb_params("updateRecordings", "")
    get(bigbluebutton_api_update_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "missingParamRecordID")
  end
  
	it("updateRecordings adds a new meta parameter") do
    r = create(:recording)
    meta_params = { "newparam" => "newvalue" }
    params = encode_bbb_params("updateRecordings", { :recordID => r.record_id }.merge(meta_params.transform_keys { |k| "meta_#{k}" }).to_query)
    expect { get(bigbluebutton_api_update_recordings_url, :params => params) }.to(change { Metadatum.count }.by(1))
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>updated", "true")
    meta_params.each do |k, v|
      m = r.metadata.find_by(:key => k)
      assert_not(m.nil?)
      expect(m.value).to(be_truthy)
    end
  end
  
	it("updateRecordings updates an existing meta parameter for a get request") do
    r = create(:recording_with_metadata, :meta_params => ({ "gl-listed" => "true" }))
    meta_params = { "gl-listed" => "false" }
    params = encode_bbb_params("updateRecordings", { :recordID => r.record_id }.merge(meta_params.transform_keys { |k| "meta_#{k}" }).to_query)
    expect { get(bigbluebutton_api_update_recordings_url, :params => params) }.to_not(change { Metadatum.count })
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>updated", "true")
    m = r.metadata.find_by(:key => "gl-listed")
    expect(meta_params["gl-listed"]).to(eq(m.value))
  end
  
	it("updateRecordings updates an existing meta parameter for a post request") do
    r = create(:recording_with_metadata, :meta_params => ({ "gl-listed" => "true" }))
    meta_params = { "gl-listed" => "true" }
    params = encode_bbb_params("updateRecordings", { :recordID => r.record_id }.merge(meta_params.transform_keys { |k| "meta_#{k}" }).to_query)
    expect do
      BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
        post(bigbluebutton_api_update_recordings_url, :params => params)
      end
    end.to_not(change { Metadatum.count })
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>updated", "true")
    m = r.metadata.find_by(:key => "gl-listed")
    expect(meta_params["gl-listed"]).to(eq(m.value))
  end
  
	it("updateRecordings deletes an existing meta parameter") do
    r = create(:recording_with_metadata, :meta_params => ({ "gl-listed" => "true" }))
    meta_params = { "gl-listed" => "" }
    params = encode_bbb_params("updateRecordings", { :recordID => r.record_id }.merge(meta_params.transform_keys { |k| "meta_#{k}" }).to_query)
    expect { get(bigbluebutton_api_update_recordings_url, :params => params) }.to(change { Metadatum.count }.by(-1))
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>updated", "true")
    expect { r.metadata.find_by!(:key => "gl-listed") }.to(raise_error(ActiveRecord::RecordNotFound))
  end
  
	it("updateRecordings updates metadata on multiple recordings") do
    r1 = create(:recording_with_metadata, :meta_params => ({ "isBreakout" => "false", "meetingName" => "Fred's Room", "gl-listed" => "false" }))
    r2 = create(:recording)
    meta_params = { "newkey" => "newvalue", "gl-listed" => "" }
    params = encode_bbb_params("updateRecordings", { :recordID => ("#{r1.record_id},#{r2.record_id}") }.merge(meta_params.transform_keys { |k| "meta_#{k}" }).to_query)
    assert_difference("r1.metadata.count" => 0, "r2.metadata.count" => 1, "Metadatum.count" => 1) do
      get(bigbluebutton_api_update_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>updated", "true")
    expect(r1.metadata.find_by(:key => "gl-listed")).to(be_nil)
    expect(r2.metadata.find_by(:key => "gl-listed")).to(be_nil)
    expect("newvalue").to(eq(r1.metadata.find_by(:key => "newkey").value))
    expect("newvalue").to(eq(r2.metadata.find_by(:key => "newkey").value))
  end
  
	it("deleteRecordings with no parameters returns checksum error") do
    get(bigbluebutton_api_delete_recordings_url)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("deleteRecordings with invalid checksum returns checksum error") do
    get(bigbluebutton_api_delete_recordings_url, :params => ("checksum=#{("x" * 40)}"))
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "checksumError")
  end
  
	it("deleteRecordings requires recordID parameter") do
    params = encode_bbb_params("deleteRecordings", "")
    get(bigbluebutton_api_delete_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "missingParamRecordID")
  end
  
	it("deleteRecordings responds with notFound if passed invalid recordIDs") do
    params = encode_bbb_params("deleteRecordings", "recordID=123")
    get(bigbluebutton_api_delete_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
  end
  
	it("deleteRecordings deletes the recording from the database if passed recordID") do
    r = create(:recording, :record_id => "test123")
    params = encode_bbb_params("deleteRecordings", "recordID=#{r.record_id}")
    get(bigbluebutton_api_delete_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>deleted", "true")
    expect(r.reload.state.eql?("deleted")).to(eq(true))
  end
  
	it("deleteRecordings deletes the recording from the database if passed recordID for a post request") do
    r = create(:recording)
    params = encode_bbb_params("deleteRecordings", "recordID=#{r.record_id}")
    BigBlueButtonApiController.stub_any_instance(:verify_checksum, nil) do
      post(bigbluebutton_api_delete_recordings_url, :params => params)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>deleted", "true")
    expect(r.reload.state.eql?("deleted")).to(eq(true))
  end
  
	it("deleteRecordings handles multiple recording IDs passed") do
    r = create(:recording)
    r1 = create(:recording)
    r2 = create(:recording)
    params = encode_bbb_params("deleteRecordings", { :recordID => [r.record_id, r1.record_id, r2.record_id].join(",") }.to_query)
    get(bigbluebutton_api_delete_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>deleted", "true")
    expect(r.reload.state.eql?("deleted")).to(eq(true))
    expect(r1.reload.state.eql?("deleted")).to(eq(true))
    expect(r2.reload.state.eql?("deleted")).to(eq(true))
  end
  
	it("getRecordings returns noRecordings if RECORDING_DISABLED flag is set to true for a get request") do
    create_list(:recording, 3)
    params = encode_bbb_params("getRecordings", "")
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    get(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>messageKey", "noRecordings")
    assert_select("response>message", "There are not recordings for the meetings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("getRecordings returns noRecordings if RECORDING_DISABLED flag is set to true for a post request") do
    create_list(:recording, 3)
    params = encode_bbb_params("getRecordings", "")
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    post(bigbluebutton_api_get_recordings_url, :params => params)
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>messageKey", "noRecordings")
    assert_select("response>message", "There are not recordings for the meetings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("publishRecordings returns notFound if RECORDING_DISABLED flag is set to true for a get request") do
    params = encode_bbb_params("publishRecordings", { :publish => "true" }.to_query)
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    get("http://www.example.com/bigbluebutton/api/publishRecordings", :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
    assert_select("response>message", "We could not find recordings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("publishRecordings returns notFound if RECORDING_DISABLED flag is set to true for a post request") do
    params = encode_bbb_params("publishRecordings", { :publish => "true" }.to_query)
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    post("http://www.example.com/bigbluebutton/api/publishRecordings", :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
    assert_select("response>message", "We could not find recordings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("updateRecordings returns notFound if RECORDING_DISABLED flag is set to true for a get request") do
    params = encode_bbb_params("updateRecordings", "")
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    get("http://www.example.com/bigbluebutton/api/updateRecordings", :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
    assert_select("response>message", "We could not find recordings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("updateRecordings returns notFound if RECORDING_DISABLED flag is set to true for a post request") do
    params = encode_bbb_params("updateRecordings", "")
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    post("http://www.example.com/bigbluebutton/api/updateRecordings", :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
    assert_select("response>message", "We could not find recordings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("deleteRecordings returns notFound if RECORDING_DISABLED flag is set to TRUE for a get request") do
    r = create(:recording)
    params = encode_bbb_params("deleteRecordings", "recordID=#{r.record_id}")
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    get("http://www.example.com/bigbluebutton/api/deleteRecordings", :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
    assert_select("response>message", "We could not find recordings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("deleteRecordings returns notFound if RECORDING_DISABLED flag is set to TRUE for a post request") do
    r = create(:recording)
    params = encode_bbb_params("deleteRecordings", "recordID=#{r.record_id}")
    Rails.configuration.x.recording_disabled = true
    reload_routes!
    post("http://www.example.com/bigbluebutton/api/deleteRecordings", :params => params)
    assert_response(:success)
    assert_select("response>returncode", "FAILED")
    assert_select("response>messageKey", "notFound")
    assert_select("response>message", "We could not find recordings")
    Rails.configuration.x.recording_disabled = false
    reload_routes!
  end
  
	it("getMeetings returns no meetings if GET_MEETINGS_API_DISABLED flag is set to true for a get request") do
    mock_env("GET_MEETINGS_API_DISABLED" => "TRUE") do
      reload_routes!
      get(bigbluebutton_api_get_meetings_url)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>messageKey", "noMeetings")
    assert_select("response>message", "no meetings were found on this server")
    assert_select("response>meetings", "")
  end
  
	it("getMeetings returns no meetings if GET_MEETINGS_API_DISABLED flag is set to true for a post request") do
    mock_env("GET_MEETINGS_API_DISABLED" => "TRUE") do
      reload_routes!
      post(bigbluebutton_api_get_meetings_url)
    end
    assert_response(:success)
    assert_select("response>returncode", "SUCCESS")
    assert_select("response>messageKey", "noMeetings")
    assert_select("response>message", "no meetings were found on this server")
    assert_select("response>meetings", "")
  end
end