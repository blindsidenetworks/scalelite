# frozen_string_literal: true

class FsapiControllerTest < ActionDispatch::IntegrationTest
  # Authentication-related tests

  def test_unauthenticated_request
    Rails.configuration.x.stub(:fsapi_password, 'password') do
      post(fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' })
    end
    assert_response(401)
    assert_match(/\ABasic realm="[^"]*"\z/, @response.headers['WWW-Authenticate'])
  end

  def test_request_with_authentication_disabled
    Rails.configuration.x.stub(:fsapi_password, '') do
      post(fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' })
    end
    assert_response(:success)
    assert_select('section[name="dialplan"]', 1)
  end

  def test_authenticated_request
    Rails.configuration.x.stub(:fsapi_password, 'password') do
      post(
        fsapi_url,
        params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' },
        headers: { HTTP_AUTHORIZATION: ActionController::HttpAuthentication::Basic.encode_credentials('fsapi', 'password') },
      )
    end
    assert_response(:success)
    assert_select('section[name="dialplan"]', 1)
  end

  # Prompt sequencing and bridging tests

  def test_initial_call_no_pin
    FsapiController.stub_any_instance(:authenticate, true) do
      post(fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' })
    end
    assert_response(:success)
    assert_select('section[name="dialplan"]', 1) do
      assert_select('context extension condition[field="destination_number"][expression="^5551234$"]', 1) do
        assert_select('action[application="answer"]')
        assert_select('action[application="playback"][data="ivr/ivr-welcome.wav"]')
        assert_select('action[application="play_and_get_digits"]')
      end
    end
  end

  def test_non_matching_pin
    FsapiController.stub_any_instance(:authenticate, true) do
      post(fsapi_url, params: { section: 'dialplan', variable_pin: '12345', 'Caller-Destination-Number': '5551234' })
    end
    assert_response(:success)
    assert_select('section[name="dialplan"]', 1) do
      assert_select('context extension condition[field="destination_number"][expression="^5551234$"]', 1) do
        assert_select('action[application="playback"][data="conference/conf-bad-pin.wav"]', 1)
        assert_select('action[application="play_and_get_digits"]')
      end
    end
  end

  def test_matching_pin
    server = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1-secret', enabled: true, load: 0)
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    voice_bridge = meeting.voice_bridge

    FsapiController.stub_any_instance(:authenticate, true) do
      post(fsapi_url, params: { section: 'dialplan', variable_pin: voice_bridge, 'Caller-Destination-Number': '5551234' })
    end
    assert_response(:success)
    assert_select('section[name="dialplan"]', 1) do
      assert_select('context extension condition[field="destination_number"][expression="^5551234$"]', 1) do
        assert_select('action[application="set"]:match("data", ?)', meeting.id)
        assert_select('action[application="set"]:match("data", ?)', 'effective_caller_id_name=Unavailable')
        assert_select(
          'action[application="bridge"]:match("data", ?)',
           "sofia/external/#{voice_bridge}@test-1.example.com"
        )
      end
    end
  end

  def test_breakout_room_pin
    server = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1-secret', enabled: true, load: 0)
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    voice_bridge = meeting.voice_bridge
    breakout_voice_bridge = "#{voice_bridge}7"

    FsapiController.stub_any_instance(:authenticate, true) do
      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: breakout_voice_bridge,
          'Caller-Destination-Number': '5551234'
        }
      )
    end
    assert_response(:success)
    assert_select('section[name="dialplan"]', 1) do
      assert_select('context extension condition[field="destination_number"][expression="^5551234$"]', 1) do
        assert_select('action[application="set"]:match("data", ?)', meeting.id)
        assert_select('action[application="set"]:match("data", ?)', 'effective_caller_id_name=Unavailable')
        assert_select(
          'action[application="bridge"]:match("data", ?)',
           "sofia/external/#{breakout_voice_bridge}@test-1.example.com"
        )
      end
    end
  end

  # Caller-Id related tests

  def test_caller_id_name
    server = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1-secret', enabled: true, load: 0)
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    voice_bridge = meeting.voice_bridge

    FsapiController.stub_any_instance(:authenticate, true) do
      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: voice_bridge,
          'Caller-Destination-Number': '5551234',
          'Caller-Caller-ID-Name': 'Test User',
        }
      )
    end
    assert_response(:success)
    assert_select('section > context > extension > condition') do
      assert_select('action[application="set"]:match("data", ?)', 'effective_caller_id_name=Test User')
    end
  end

  def test_caller_id_name_hidden
    server = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1-secret', enabled: true, load: 0)
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    voice_bridge = meeting.voice_bridge

    FsapiController.stub_any_instance(:authenticate, true) do
      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: voice_bridge,
          'Caller-Destination-Number': '5551234',
          'Caller-Caller-ID-Name': 'Test User',
          'Caller-Privacy-Hide-Name': 'true',
        }
      )
    end
    assert_response(:success)
    assert_select('section > context > extension > condition') do
      assert_select('action[application="set"]:match("data", ?)', 'effective_caller_id_name=Unavailable')
    end
  end

  def test_caller_id_number_masked
    server = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1-secret', enabled: true, load: 0)
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    voice_bridge = meeting.voice_bridge

    FsapiController.stub_any_instance(:authenticate, true) do
      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: voice_bridge,
          'Caller-Destination-Number': '5551234',
          'Caller-Caller-ID-Name': '5554321',
        }
      )
    end
    assert_response(:success)
    assert_select('section > context > extension > condition') do
      assert_select('action[application="set"]:match("data", ?)', 'effective_caller_id_name=555XXXX')
    end
  end

  def test_caller_id_number_hidden
    server = Server.create(url: 'https://test-1.example.com/bigbluebutton/api/', secret: 'test-1-secret', enabled: true, load: 0)
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    voice_bridge = meeting.voice_bridge

    FsapiController.stub_any_instance(:authenticate, true) do
      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: voice_bridge,
          'Caller-Destination-Number': '5551234',
          'Caller-Caller-ID-Name': '5554321',
          'Caller-Privacy-Hide-Number': 'true',
        }
      )
    end
    assert_response(:success)
    assert_select('section > context > extension > condition') do
      assert_select('action[application="set"]:match("data", ?)', 'effective_caller_id_name=Unavailable')
    end
  end

  # Timeout related tests

  def test_pin_prompt_allotted_timeout_not_set
    Rails.configuration.x.stub(:fsapi_max_duration, 0) do
      FsapiController.stub_any_instance(:authenticate, true) do
        post(fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' })
      end
    end
    assert_response(:success)
    assert_select('section > context > extension > condition') do
      assert_select('action[application="sched_hangup"]', 0)
    end
  end

  def test_pin_prompt_allotted_timeout
    Rails.configuration.x.stub(:fsapi_max_duration, 90) do
      FsapiController.stub_any_instance(:authenticate, true) do
        post(fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' })
      end
    end
    assert_response(:success)
    Rails.logger.debug { @response.body }
    assert_select('section > context > extension > condition') do
      assert_select('action[application="sched_hangup"][data="+5400 normal_clearing"]')
    end
  end
end
