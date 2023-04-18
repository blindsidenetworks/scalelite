# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaybackController, type: :request do
  describe 'playback' do
    let!(:recording) { create(:recording) }

    it 'gets playback' do
      get "/playback/presentation/2.0/#{recording.record_id}"

      expect(response.status).to eq 200
    end

    it 'renders 404 if the recording url is invalid' do
      get "/recording/invalid_recording_id/invalid_format"

      expect(response.status).to eq 404
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
        expect(response.status).to eq 200
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
          expect(response.status).to eq 200
        end

        it 'blocks resource access if enabled' do
          Rails.configuration.x.protected_recordings_enabled = true
          get "/#{playback_format.format}/#{recording.record_id}/slides.svg"

          expect(response.status).to eq 404
          expect(@response.has_header?('X-Accel-Redirect')).to eq false
        end
      end
    end
  end
end
