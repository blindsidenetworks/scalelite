# frozen_string_literal: true

module BigBlueButtonApiHelper
  require 'uri'
  include ApiHelper

  def self.recording_url(playback_format, url_prefix)
    recording = playback_format.recording
    url = "#{url_prefix}#{playback_format.url}"
    return url unless recording.protected

    token = playback_format.create_protector_token
    uri = URI.parse(url)
    params = Hash[URI.decode_www_form(uri.query || '')].merge(token: token)
    uri.query = URI.encode_www_form(params)
    uri.to_s
  end
end
