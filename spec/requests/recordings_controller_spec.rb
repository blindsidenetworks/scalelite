# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::RecordingsController do
  include ApiHelper

  let(:secret) { 'expired-recording-test-secret' }
  let(:auth_headers) { { 'Authorization' => "Bearer #{secret}" } }
  let!(:recording) { create(:recording_with_metadata, :published) }

  before do
    allow(Rails.configuration.x).to receive(:recording_expired_secret).and_return(secret)
    create(:playback_format, recording: recording)
  end

  def post_expired(params: { id: recording.record_id }, headers: auth_headers)
    post scalelite_api_expired_recording_url, params: params, headers: headers, as: :json
  end

  describe 'POST #expired_recording' do
    context 'with a valid secret' do
      it 'marks an existing recording as deleted and removes its metadata and playback formats' do
        post_expired
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to have_key('success')

        recording.reload
        expect(recording.state).to eq('deleted')
        expect(recording.metadata.count).to eq(0)
        expect(recording.playback_formats.count).to eq(0)
      end

      it 'accepts the Bearer scheme case-insensitively' do
        post_expired(headers: { 'Authorization' => "bearer #{secret}" })
        expect(response).to have_http_status(:ok)
        expect(recording.reload.state).to eq('deleted')
      end

      it 'returns ok and changes nothing when the recording is already deleted' do
        recording.update!(state: 'deleted')
        post_expired
        expect(response).to have_http_status(:ok)

        recording.reload
        expect(recording.state).to eq('deleted')
        expect(recording.metadata.count).to eq(3)
      end

      it 'returns not found for an unknown recording id' do
        post_expired(params: { id: 'unknown-record-id' })
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to have_key('error')
      end

      it 'returns bad request when the id is missing' do
        post_expired(params: {})
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns bad request when the id is blank' do
        post_expired(params: { id: '' })
        expect(response).to have_http_status(:bad_request)
      end

      it 'returns bad request when the id is not a string' do
        post_expired(params: { id: [recording.record_id] })
        expect(response).to have_http_status(:bad_request)
        expect(recording.reload.state).to eq('published')
      end

      it 'returns unsupported media type as JSON for a non-JSON body' do
        post scalelite_api_expired_recording_url, params: { id: recording.record_id }, headers: auth_headers
        expect(response).to have_http_status(:unsupported_media_type)
        expect(response.media_type).to eq('application/json')
        expect(recording.reload.state).to eq('published')
      end

      it 'returns internal server error without logging the secret when deletion fails' do
        allow_any_instance_of(Recording).to receive(:mark_delete!).and_raise(StandardError, 'boom')
        allow(Rails.logger).to receive(:error).and_call_original

        post_expired
        expect(response).to have_http_status(:internal_server_error)
        expect(Rails.logger).to have_received(:error).with(satisfy { |msg| msg.to_s.exclude?(secret) }).at_least(:once)
        expect(Rails.logger).not_to have_received(:error).with(satisfy { |msg| msg.to_s.include?(secret) })
      end
    end

    context 'with a missing, malformed or wrong secret' do
      {
        'no Authorization header' => nil,
        'a wrong token' => 'Bearer wrong-secret',
        'a token that differs only in length' => 'Bearer expired-recording-test-secretX',
        'the Token scheme' => 'Token expired-recording-test-secret',
        'the Basic scheme' => "Basic #{Base64.strict_encode64('user:expired-recording-test-secret')}",
        'trailing options after the token' => 'Bearer expired-recording-test-secret,extra=1',
        'two spaces after the scheme' => 'Bearer  expired-recording-test-secret',
        'an empty token' => 'Bearer ',
      }.each do |description, header|
        it "returns unauthorized for #{description} and leaves the recording unchanged" do
          post_expired(headers: header.nil? ? {} : { 'Authorization' => header })
          expect(response).to have_http_status(:unauthorized)
          expect(recording.reload.state).to eq('published')
        end
      end

      it 'returns unauthorized for a valid loadbalancer checksum without a bearer token' do
        allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['lb-secret'])
        url = URI(scalelite_api_expired_recording_url)
        url.query = "checksum=#{Digest::SHA256.hexdigest('expiredRecordinglb-secret')}"

        post url.to_s, params: { id: recording.record_id }, as: :json
        expect(response).to have_http_status(:unauthorized)
        expect(recording.reload.state).to eq('published')
      end
    end

    context 'when the secret is not configured' do
      attempted_headers = ['Bearer anything', 'Bearer ', nil].freeze

      [nil, ''].each do |configured|
        it "returns unauthorized for any token when the secret is #{configured.inspect}" do
          allow(Rails.configuration.x).to receive(:recording_expired_secret).and_return(configured)

          attempted_headers.each do |header|
            post_expired(headers: header.nil? ? {} : { 'Authorization' => header })
            expect(response).to have_http_status(:unauthorized)
          end
          expect(recording.reload.state).to eq('published')
        end
      end
    end
  end

  describe 'scope of the recording-expired secret' do
    it 'does not grant access to other scalelite admin endpoints' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['lb-secret'])
      create(:server)

      get scalelite_api_get_servers_url, headers: auth_headers
      expect(response.body).to include('checksumError')
      expect(response.body).not_to include('"url"')
    end
  end
end
