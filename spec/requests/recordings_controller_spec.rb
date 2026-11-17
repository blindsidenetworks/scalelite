# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::RecordingsController do
  include ApiHelper

  let(:secret) { 'expired-recording-test-secret' }
  let!(:recording) { create(:recording_with_metadata, :published) }

  before do
    allow(Rails.configuration.x).to receive(:recording_expired_secret).and_return(secret)
    create(:playback_format, recording: recording)
  end

  def token_for(record_id = recording.record_id, exp: 5.minutes.from_now.to_i, key: secret, algorithm: 'HS512', **extra)
    payload = { record_id: record_id, exp: exp }.merge(extra).compact
    JWT.encode(payload, key, algorithm)
  end

  def bearer(token)
    { 'Authorization' => "Bearer #{token}" }
  end

  def post_expired(headers: bearer(token_for), params: nil)
    post scalelite_api_expired_recording_url, params: params, headers: headers, as: (params.nil? ? nil : :json)
  end

  describe 'POST #expired_recording' do
    context 'with a valid token' do
      it 'marks the recording named in the token as deleted and removes its metadata and playback formats' do
        post_expired
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to have_key('success')

        recording.reload
        expect(recording.state).to eq('deleted')
        expect(recording.metadata.count).to eq(0)
        expect(recording.playback_formats.count).to eq(0)
      end

      it 'accepts the Bearer scheme case-insensitively' do
        post_expired(headers: { 'Authorization' => "bearer #{token_for}" })
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
        post_expired(headers: bearer(token_for('unknown-record-id')))
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to have_key('error')
      end

      it 'ignores an id in the request body and acts only on the recording named in the token' do
        other = create(:recording_with_metadata, :published)
        post_expired(params: { id: other.record_id })
        expect(response).to have_http_status(:ok)
        expect(recording.reload.state).to eq('deleted')
        expect(other.reload.state).to eq('published')
      end

      it 'returns internal server error without logging the token when deletion fails' do
        token = token_for
        allow_any_instance_of(Recording).to receive(:mark_delete!).and_raise(StandardError, 'boom')
        allow(Rails.logger).to receive(:error).and_call_original

        post_expired(headers: bearer(token))
        expect(response).to have_http_status(:internal_server_error)
        expect(Rails.logger).to have_received(:error).at_least(:once)
        expect(Rails.logger).not_to have_received(:error).with(satisfy { |msg| msg.to_s.include?(token) || msg.to_s.include?(secret) })
      end
    end

    context 'with a missing, invalid or expired token' do
      {
        'no Authorization header' => -> { {} },
        'the raw secret as the bearer value' => -> { bearer(secret) },
        'an expired token' => -> { bearer(token_for(exp: 1.minute.ago.to_i)) },
        'a token signed with the wrong secret' => -> { bearer(token_for(key: 'wrong-secret')) },
        'a token without exp' => -> { bearer(token_for(exp: nil)) },
        'a token without record_id' => -> { bearer(token_for(nil)) },
        'a token with a non-string record_id' => -> { bearer(token_for([recording.record_id])) },
        'a token signed with a different algorithm' => -> { bearer(token_for(algorithm: 'HS256')) },
        'an unsigned token (alg none)' => -> { bearer(token_for(key: nil, algorithm: 'none')) },
        'the Token scheme' => -> { { 'Authorization' => "Token #{token_for}" } },
        'the Basic scheme' => -> { { 'Authorization' => "Basic #{Base64.strict_encode64("user:#{secret}")}" } },
        'trailing options after the token' => -> { { 'Authorization' => "Bearer #{token_for},extra=1" } },
        'two spaces after the scheme' => -> { { 'Authorization' => "Bearer  #{token_for}" } },
        'an empty token' => -> { { 'Authorization' => 'Bearer ' } },
      }.each do |description, headers|
        it "returns unauthorized for #{description} and leaves the recording unchanged" do
          post_expired(headers: instance_exec(&headers))
          expect(response).to have_http_status(:unauthorized)
          expect(recording.reload.state).to eq('published')
        end
      end

      it 'returns unauthorized for a valid loadbalancer checksum without a token' do
        allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['lb-secret'])
        url = URI(scalelite_api_expired_recording_url)
        url.query = "checksum=#{Digest::SHA256.hexdigest('expiredRecordinglb-secret')}"

        post url.to_s
        expect(response).to have_http_status(:unauthorized)
        expect(recording.reload.state).to eq('published')
      end
    end

    context 'when the secret is not configured' do
      [nil, ''].each do |configured|
        it "returns unauthorized when the secret is #{configured.inspect}" do
          allow(Rails.configuration.x).to receive(:recording_expired_secret).and_return(configured)

          post_expired(headers: bearer(token_for(key: 'anything')))
          expect(response).to have_http_status(:unauthorized)
          post_expired(headers: {})
          expect(response).to have_http_status(:unauthorized)
          expect(recording.reload.state).to eq('published')
        end
      end
    end
  end

  describe 'scope of the recording-expired secret' do
    it 'does not grant access to other scalelite admin endpoints' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['lb-secret'])
      create(:server)

      get scalelite_api_get_servers_url, headers: bearer(token_for)
      expect(response.body).to include('checksumError')
      expect(response.body).not_to include('"url"')
    end
  end
end
