# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FsapiController, type: :request do
  # Authentication-related tests

  context 'unauthenticated request' do
    it 'returns 401 Unauthorized and sets WWW-Authenticate header' do
      allow(Rails.configuration.x).to receive(:fsapi_password).and_return('password')

      post fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' }

      expect(response).to have_http_status(401)
      expect(response.headers['WWW-Authenticate']).to match(/\ABasic realm="[^"]*"\z/)
    end
  end

  context 'request with authentication disabled' do
    it 'responds with success' do
      allow(Rails.configuration.x).to receive(:fsapi_password).and_return('')

      post fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' }

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)
      section_elements = xml_response.search('section[@name="dialplan"]')
      expect(section_elements.count).to eq(1)
    end
  end

  context 'authenticated request' do
    it 'responds with success' do
      allow(Rails.configuration.x).to receive(:fsapi_password).and_return('password')

      post(
        fsapi_url,
        params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' },
        headers: { HTTP_AUTHORIZATION: ActionController::HttpAuthentication::Basic.encode_credentials('fsapi', 'password') },
      )

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)
      section_elements = xml_response.search('section[@name="dialplan"]')
      expect(section_elements.count).to eq(1)
    end
  end

  # Prompt sequencing and bridging tests

  context 'initial call with no pin' do
    it 'responds with success and correct dialplan' do
      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

      post fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' }

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      section = xml_response.search('section[@name="dialplan"]')
      expect(section.count).to eq(1)

      condition = section.search('condition[@field="destination_number"][@expression="^5551234$"]')
      expect(condition.count).to eq(1)

      answer = condition.at('action[@application="answer"]')
      expect(answer).not_to be_nil

      playback = condition.at('action[@application="playback"][@data="ivr/ivr-welcome.wav"]')
      expect(playback).not_to be_nil

      play_and_get_digits = condition.at('action[@application="play_and_get_digits"]')
      expect(play_and_get_digits).not_to be_nil
    end
  end

  context 'non-matching pin' do
    it 'responds with success and correct dialplan' do
      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

      post fsapi_url, params: { section: 'dialplan', variable_pin: '12345', 'Caller-Destination-Number': '5551234' }

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      section = xml_response.search('section[name="dialplan"]')
      expect(section.count).to eq(1)

      condition = section.search('context extension condition[field="destination_number"][expression="^5551234$"]')
      expect(condition.count).to eq(1)

      playback_action = condition.search('action[application="playback"][data="conference/conf-bad-pin.wav"]')
      expect(playback_action.count).to eq(1)

      play_and_get_digits = condition.at('action[application="play_and_get_digits"]')
      expect(play_and_get_digits).not_to be_nil
    end
  end

  context 'matching pin' do
    it 'responds with success and correct dialplan' do
      meeting = create(:meeting)
      voice_bridge = meeting.voice_bridge

      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

      post fsapi_url, params: { section: 'dialplan', variable_pin: voice_bridge, 'Caller-Destination-Number': '5551234' }

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      section = xml_response.search('section[name="dialplan"]')
      expect(section.count).to eq(1)

      condition = section.search('context extension condition[field="destination_number"][expression="^5551234$"]')
      expect(condition.count).to eq(1)

      set_meeting_id = condition.at(".//action[@application='set'][@data='meeting_id=#{meeting.id}']")
      expect(set_meeting_id).not_to be_nil

      set_effective_caller_id_name = condition.at(".//action[@application='set'][@data='effective_caller_id_name=Unavailable']")
      expect(set_effective_caller_id_name).not_to be_nil

      bridge = condition.at(".//action[@application='bridge'][@data='sofia/external/#{voice_bridge}@test-1.example.com']")
      expect(bridge).not_to be_nil
    end
  end

  context 'breakout room pin' do
    it 'responds with success and correct dialplan' do
      meeting = create(:meeting)
      voice_bridge = meeting.voice_bridge
      breakout_voice_bridge = "#{voice_bridge}7"

      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: breakout_voice_bridge,
          'Caller-Destination-Number': '5551234'
        }
      )

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      section = xml_response.search('section[@name="dialplan"]')
      expect(section.count).to eq(1)

      condition = xml_response.search('context extension condition[@field="destination_number"][@expression="^5551234$"]')
      expect(condition.count).to eq(1)

      set_meeting_id = condition.at(".//action[@application='set'][@data='meeting_id=#{meeting.id}']")
      expect(set_meeting_id).not_to be_nil

      set_effective_caller_id_name = xml_response.at(".//action[@application='set'][@data='effective_caller_id_name=Unavailable']")
      expect(set_effective_caller_id_name).not_to be_nil

      bridge = xml_response.at(".//action[@application='bridge'][@data='sofia/external/#{breakout_voice_bridge}@test-1.example.com']")
      expect(bridge).not_to be_nil
    end
  end

  # Caller-Id related tests

  context "effective caller id name" do
    it "returns caller name" do
      meeting = create(:meeting)
      voice_bridge = meeting.voice_bridge

      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: voice_bridge,
          'Caller-Destination-Number': '5551234',
          'Caller-Caller-ID-Name': 'Test User',
        }
      )

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      condition_element = xml_response.at('section > context > extension > condition')
      expect(condition_element).not_to be_nil

      action_element = condition_element.search('.//action[@application="set" and @data="effective_caller_id_name=Test User"]')
      expect(action_element).not_to be_nil
    end

    it "does not return caller name if privacy hide name is set to true" do
      meeting = create(:meeting)
      voice_bridge = meeting.voice_bridge

      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

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

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      condition_element = xml_response.at('section > context > extension > condition')
      expect(condition_element).not_to be_nil

      action_element = condition_element.search('.//action[@application="set" and @data="effective_caller_id_name=Unavailable"]')
      expect(action_element).not_to be_nil
    end
  end

  context 'effective caller id number' do
    it "returns masked caller number" do
      meeting = create(:meeting)
      voice_bridge = meeting.voice_bridge

      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)
      post(
        fsapi_url,
        params: {
          section: 'dialplan',
          variable_pin: voice_bridge,
          'Caller-Destination-Number': '5551234',
          'Caller-Caller-ID-Name': '5554321',
        }
      )

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      condition_element = xml_response.at('section > context > extension > condition')
      expect(condition_element).not_to be_nil

      action_element = condition_element.search('.//action[@application="set" and @data="effective_caller_id_number=555XXXX"]')
      expect(action_element).not_to be_nil
    end

    it 'does not return masked caller number if privacy hide number is set to true' do
      meeting = create(:meeting)
      voice_bridge = meeting.voice_bridge

      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

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

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      condition_element = xml_response.at('section > context > extension > condition')
      expect(condition_element).not_to be_nil

      action_element = condition_element.search('.//action[@application="set" and @data="effective_caller_id_number=Unavailable"]')
      expect(action_element).not_to be_nil
    end
  end

  # Timeout related tests

  context 'fullswitch max duration set to 90' do
    it 'returns sched_hangup' do
      allow(Rails.configuration.x).to receive(:fsapi_max_duration).and_return(90)
      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

      post fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' }

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      condition_element = xml_response.at('section > context > extension > condition')
      expect(condition_element).not_to be_nil

      action_element = condition_element.at('action[application="sched_hangup"][data="+5400 normal_clearing"]')
      expect(action_element).not_to be_nil
    end
  end

  context 'fullswitch max duration not set' do
    it 'does not return sched_hangup' do
      allow(Rails.configuration.x).to receive(:fsapi_max_duration).and_return(0)
      allow_any_instance_of(FsapiController).to receive(:authenticate).and_return(true)

      post fsapi_url, params: { section: 'dialplan', 'Caller-Destination-Number': '5551234' }

      expect(response).to have_http_status(:success)
      xml_response = Nokogiri::XML(response.body)

      condition_element = xml_response.at('section > context > extension > condition')
      expect(condition_element).not_to be_nil

      action_element = condition_element.search('action[application="sched_hangup"]')
      expect(action_element).to be_empty
    end
  end
end
