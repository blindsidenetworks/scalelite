# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaybackController do
  before do
    Rails.configuration.x.multitenancy_enabled = false
  end

  describe 'playback' do
    let!(:recording) { create(:recording) }

    it 'gets playback' do
      get "/playback/presentation/2.0/#{recording.record_id}"

      expect(response).to have_http_status :ok
    end

    it 'renders 404 if the recording url is invalid' do
      get "/recording/invalid_recording_id/invalid_format"

      expect(response).to have_http_status :not_found
      expect(response).to render_template 'errors/recording_not_found'
    end

    context 'with js file' do
      let!(:recording) { create(:recording, :published, state: 'published') }
      let!(:playback_format) {
        create(
          :playback_format,
        recording: recording,
        format: 'capture',
        url: "/capture/#{recording.record_id}/"
        )
      }

      it 'renders properly' do
        get "#{playback_format.url}capture.js"
        expect(response).to have_http_status :ok
        expect(response.get_header('X-Accel-Redirect')).to eq "/static-resource#{playback_format.url}capture.js"
      end
    end

    context 'with protected recording' do
      let!(:recording) { create(:recording, :published, state: 'published', protected: true) }
      let!(:playback_format) {
        create(
          :playback_format,
        recording: recording,
        format: 'capture',
        url: "/playback/presentation/index.html?meetingID=#{recording.record_id}"
        )
      }

      context 'without cookies' do
        it 'allows resource access if disabled' do
          get "/#{playback_format.format}/#{recording.record_id}/slides.svg"
          expect(response).to have_http_status :ok
        end

        it 'blocks resource access if enabled' do
          Rails.configuration.x.protected_recordings_enabled = true
          get "/#{playback_format.format}/#{recording.record_id}/slides.svg"

          expect(response).to have_http_status :not_found
          expect(response.has_header?('X-Accel-Redirect')).to be false
        end

        it 'rejects a cookie from another recording' do
          Rails.configuration.x.protected_recordings_enabled = true
          another_recording = create(:recording, :published, state: 'published', protected: true)
          another_playback_format = create(
            :playback_format,
            recording: another_recording,
            format: playback_format.format,
            url: "/#{playback_format.format}/#{another_recording.record_id}/index.html"
          )

          resource_path = "/#{playback_format.format}/#{recording.record_id}"
          payload = { 'sub' => resource_path, 'exp' => 1.hour.from_now.to_i }
          secret = Rails.configuration.secrets.secret_key_base
          token = JWT.encode(payload, secret, 'HS256')

          cookies["recording_#{another_playback_format.format}_#{another_recording.record_id}"] = token

          get "/#{another_playback_format.format}/#{another_recording.record_id}/slides.svg"

          expect(response).to have_http_status :not_found
          expect(response.has_header?('X-Accel-Redirect')).to be false
        end
      end
    end

    context 'multitenancy' do
      let(:host_name) { 'api.rna1.blindside-dev.com' }
      let(:host) { "bn.#{host_name}" }
      let!(:tenant) { create(:tenant, name: 'bn') }
      let!(:tenant1) { create(:tenant) }

      before do
        Rails.configuration.x.multitenancy_enabled = true

        host! host
      end

      it "serves the same recording under a different tenant host when multitenancy is enabled" do
        recording = create(:recording, :published, state: "published")

        create(:metadatum, recording: recording, key: "tenant-id", value: tenant.id)

        create(
          :playback_format,
          recording: recording,
          format: "presentation",
          url: "/presentation/#{recording.record_id}/index.html"
        )

        path = "/presentation/#{recording.record_id}/index.html"

        get path, headers: { "HOST" => host }
        expect(response).to have_http_status(:ok)
        expect(response.get_header("X-Accel-Redirect")).to eq("/static-resource#{path}")

        get path, headers: { "HOST" => "#{tenant1.name}.#{host_name}" }
        expect(response).to have_http_status :not_found
        expect(response).to render_template 'errors/recording_not_found'
      end
    end
  end
end
