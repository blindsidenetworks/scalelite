# frozen_string_literal: true

module BigBlueButtonApiHelper
  require 'uri'
  include ApiHelper

  def self.recording_url(recording, url_prefix, format_url)
    if recording.protected
      token = recording.generate_token
      url = url_prefix + format_url
      uri = ::URI.parse(url)
      params = Hash[URI.decode_www_form(uri.query || '')].merge(token: token)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    else
      "#{url_prefix}#{format_url}/"
    end
  end
end
