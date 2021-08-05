# frozen_string_literal: true

module BigBlueButtonApiHelper
  require 'uri'
  include ApiHelper

  def self.recording_url(playback_format, url_prefix)
    recording = playback_format.recording
    unless recording.protected
      return url_prefix + playback_play_path(record_id: recording.record_id, playback_format: playback_format.format)
    end

    token = playback_format.create_protector_token
    url_prefix + playback_play_path(record_id: recording.record_id, playback_format: playback_format.format, token: token)
  end
end
