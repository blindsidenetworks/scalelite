# frozen_string_literal: true

# spec/controllers/servers_controller_spec.rb

require 'rails_helper'

RSpec.describe Api::ServersController do
  include ApiHelper

  before do
    # Disabling the checksum for the specs and re-enable it only when testing specifically the checksum
    allow_any_instance_of(described_class).to receive(:verify_checksum).and_return(true)
  end

  describe 'GET #servers' do
    it 'returns a list of configured BigBlueButton servers' do
      servers = create_list(:server, 3)
      get scalelite_api_get_servers_url
      expect(response).to have_http_status(:ok)
      server_list = response.parsed_body
      expect(server_list.size).to eq(3)

      server_list.each do |server_data|
        server = servers.find { |s| s.id == server_data['id'] }
        expect(server).not_to be_nil
        expect(server_data['url']).to eq(server.url)
        expect(server_data['secret']).to eq(server.secret)
        expect(server_data['tag']).to eq(server.tag.nil? ? '' : server.tag)
        expect(server_data['state']).to eq(if server.state.present?
                                          server.state
                                          else
                                          (server.enabled ? 'enabled' : 'disabled')
                                          end)
        expect(server_data['load']).to eq(server.load.presence || 'unavailable')
        expect(server_data['load_multiplier']).to eq(server.load_multiplier.nil? ? 1.0 : server.load_multiplier.to_d)
        expect(server_data['online']).to eq(server.online ? 'online' : 'offline')
      end
    end

    it 'returns a message if no servers are configured' do
      get scalelite_api_get_servers_url
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq('No servers are configured')
    end
  end

  describe 'POST #addServer' do
    context 'with valid parameters' do
      let(:valid_params) {
        { url: 'https://example.com/bigbluebutton',
          secret: 'supersecret',
          load_multiplier: 1.5,
          tag: 'test-tag' }
      }

      it 'creates a new BigBlueButton server' do
        expect { post scalelite_api_add_server_url, params: { server: valid_params }, as: :json }.to change { Server.all.count }.by(1)
        expect(response).to have_http_status(:created)
        response_data = response.parsed_body
        server = Server.find(response_data['id'])
        expect(server.url).to eq(valid_params[:url])
        expect(server.secret).to eq(valid_params[:secret])
        expect(server.load_multiplier).to eq(valid_params[:load_multiplier].to_s)
        expect(server.tag).to eq(valid_params[:tag])
      end

      it 'defaults load_multiplier to 1.0 if not provided' do
        post scalelite_api_add_server_url, params: { server: valid_params.except(:load_multiplier) }, as: :json
        expect(response).to have_http_status(:created)
        server = Server.find(response.parsed_body['id'])
        expect(server.load_multiplier.to_d).to eq(1.0)
      end
    end

    context 'with invalid parameters' do
      it 'renders an error message if URL is missing' do
        post scalelite_api_add_server_url, params: { server: { url: 'https://example.com/bigbluebutton' } }, as: :json
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('Server needs a URL and a secret')
      end

      it 'renders an error message if secret is missing' do
        post scalelite_api_add_server_url, params: { server: { secret: 'supersecret' } }, as: :json
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq('Server needs a URL and a secret')
      end
    end
  end

  describe 'PUT #updateServer' do
    context 'when updating state' do
      it 'updates the server state to "enabled"' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { state: 'enable' } }, as: :json
        updated_server = Server.find(server.id) # Reload
        expect(updated_server.state).to eq('enabled')
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(updated_server.id)
        expect(response.parsed_body['state']).to eq(updated_server.state)
      end

      it 'updates the server state to "cordoned"' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { state: 'cordon' } }, as: :json
        updated_server = Server.find(server.id) # Reload
        expect(updated_server.state).to eq('cordoned')
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(updated_server.id)
        expect(response.parsed_body['state']).to eq(updated_server.state)
      end

      it 'updates the server state to "disabled"' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { state: 'disable' } }, as: :json
        updated_server = Server.find(server.id) # Reload
        expect(updated_server.state).to eq('disabled')
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(updated_server.id)
        expect(response.parsed_body['state']).to eq(updated_server.state)
      end

      it 'returns an error for an invalid state parameter' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { state: 'invalid_state' } }, as: :json
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq("Invalid state parameter: invalid_state")
      end
    end

    context 'when updating load_multiplier' do
      it 'updates the server load_multiplier' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { load_multiplier: '2.5' } }, as: :json
        updated_server = Server.find(server.id) # Reload
        expect(updated_server.load_multiplier).to eq("2.5")
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(updated_server.id)
        expect(response.parsed_body['load_multiplier']).to eq(updated_server.load_multiplier)
      end

      it 'returns an error for an invalid load_multiplier parameter' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { load_multiplier: 0 } }, as: :json
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['error']).to eq("Load-multiplier must be a non-zero number")
      end
    end

    context 'when updating tag' do
      it 'updates the server tag' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { tag: 'test-tag' } }, as: :json
        updated_server = Server.find(server.id) # Reload
        expect(updated_server.tag).to eq("test-tag")
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(updated_server.id)
        expect(response.parsed_body['tag']).to eq(updated_server.tag)
      end

      it 'updates the server tag back to nil' do
        server = create(:server)
        post scalelite_api_update_server_url, params: { id: server.id, server: { tag: 'test-tag' } }, as: :json
        updated_server = Server.find(server.id) # Reload
        expect(updated_server.tag).to eq("test-tag")
        post scalelite_api_update_server_url, params: { id: server.id, server: { tag: '' } }, as: :json
        updated_server = Server.find(server.id) # Reload
        expect(updated_server.tag).to be_nil
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(updated_server.id)
        expect(response.parsed_body['tag']).to eq('')
      end
    end
  end

  describe 'DELETE #deleteServer' do
    context 'with an existing server' do
      it 'deletes the server' do
        server = create(:server)
        expect { post scalelite_api_delete_server_url, params: { id: server.id }, as: :json }.to change { Server.all.count }.by(-1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['success']).to eq("Server id=#{server.id} was destroyed")
      end
    end

    context 'with a non-existent server' do
      it 'does not delete any server' do
        post scalelite_api_delete_server_url, params: { id: 'nonexistent-id' }, as: :json
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq("Couldn't find server with id=nonexistent-id")
      end
    end
  end

  describe 'POST #panicServer' do
    it 'marks the server as unavailable and clears all meetings from it' do
      server = create(:server)
      meeting1 = create(:meeting, server: server)
      meeting2 = create(:meeting, server: server)

      expect(Meeting.all.count).to eq(2)

      stub_params_meeting1 = {
        meetingID: meeting1.id,
        password: 'pw',
      }

      stub_params_meeting2 = {
        meetingID: meeting2.id,
        password: 'pw',
      }

      stub_request(:get, encode_bbb_uri("end", server.url, server.secret, stub_params_meeting1))
        .to_return(body: "<response><returncode>SUCCESS</returncode><messageKey>OK</messageKey>
                      <message>The meeting was ended successfully.</message></response>")

      stub_request(:get, encode_bbb_uri("end", server.url, server.secret, stub_params_meeting2))
        .to_return(body: "<response><returncode>SUCCESS</returncode><messageKey>OK</messageKey>
                      <message>The meeting was ended successfully.</message></response>")

      post scalelite_api_panic_server_url, params: { id: server.id }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['success']).to eq("Server id=#{server.id} has been disabled and the meetings have been destroyed")
      panicked_server = Server.find(server.id) # Reload
      expect(panicked_server.state).to eq('disabled')
      expect(Meeting.all.count).to eq(0)
    end

    it 'keeps server state if keep_state is true' do
      server = create(:server, state: 'enabled')

      post scalelite_api_panic_server_url, params: { id: server.id, keep_state: true }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['success']).to eq("Server id=#{server.id} has been disabled and the meetings have been destroyed")
      server = Server.find(server.id) # Reload
      expect(server.state).to eq('enabled')
      expect(Meeting.all.count).to eq(0)
    end

    it 'returns an error message if the server is not found' do
      post scalelite_api_panic_server_url, params: { id: 'nonexistent_id' }, as: :json

      expect(response).to have_http_status(:not_found)
      json = response.parsed_body
      expect(json['error']).to eq("Couldn't find server with id=nonexistent_id")
    end
  end

  describe 'verify_checksum' do
    before do
      allow_any_instance_of(described_class).to receive(:verify_checksum).and_call_original
    end

    let(:valid_params) {
      { url: 'https://example.com/bigbluebutton',
        secret: 'supersecret',
        load_multiplier: 1.5 }
    }

    it 'successfully creates a server with checksum value computed using SHA1' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha1-secret'])
      url = URI(scalelite_api_add_server_url)
      url.query = "checksum=#{Digest::SHA1.hexdigest('addServersha1-secret')}"
      post(url.to_s, params: { server: valid_params }, as: :json)
      expect(response).to have_http_status(:created)
    end

    it 'successfully creates a server with checksum value computed using SHA256' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha256-secret'])
      url = URI(scalelite_api_add_server_url)
      url.query = "checksum=#{Digest::SHA256.hexdigest('addServersha256-secret')}"
      post(url.to_s, params: { server: valid_params }, as: :json)
      expect(response).to have_http_status(:created)
    end

    it 'returns a checksum error if the wrong secret is used' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha1-secret'])

      url = URI(scalelite_api_add_server_url)
      url.query = "checksum=#{Digest::SHA1.hexdigest('addServersha1-secret-incorrect')}"
      post(url.to_s, params: { server: valid_params }, as: :json)

      xml_response = Nokogiri::XML(response.body)
      expect(xml_response.at_xpath("//response/returncode").text).to eq("FAILED")
      expect(xml_response.at_xpath("//response/messageKey").text).to eq("checksumError")
    end

    it 'returns an error if the wrong content type is used' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha1-secret'])

      url = URI(scalelite_api_add_server_url)
      url.query = "checksum=#{Digest::SHA1.hexdigest('addServersha1-secret')}"
      post(url.to_s, params: { server: valid_params }, as: :url_encoded_form)

      xml_response = Nokogiri::XML(response.body)
      expect(xml_response.at_xpath('/response/returncode').content).to eq('FAILED')
      expect(xml_response.at_xpath('/response/messageKey').content).to eq('unsupportedContentType')
    end
  end
end
