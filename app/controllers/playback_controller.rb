# frozen_string_literal: true

class PlaybackController < ApplicationController
  include CookieSameSiteCompat

  class RecordingNotFoundError < StandardError
  end

  rescue_from(
    ActiveRecord::RecordNotFound,
    RecordingNotFoundError,
    PlaybackFormat::ProtectorTokenError,
    with: :recording_not_found
  )

  # The resource end point is a wrapper over static file serving. The files might include Javascript, which
  # would be blocked by Rails default CSRF protection - but these are static Javascript files which in
  # recording playback files are expected not to contain any sensitive user data. (Sensitive data should be
  # in json or xml files that are protected by browser cross-site request mechanisms.)
  skip_forgery_protection only: [:resource]

  def play
    @playback_format = PlaybackFormat
                       .joins(:recording)
                       .find_by!(format: params[:playback_format], recordings: { record_id: params[:record_id] })
    @recording = @playback_format.recording

    if @recording.protected
      # Consume the one-time-use token (return an error if missing/invalid)
      payload = PlaybackFormat.consume_protector_token(params[:token])
      raise RecordingNotFoundError if payload['record_id'] != @recording.record_id || payload['format'] != @playback_format.format

      # Set the cookie that will provide access to resources for this recording & playback format
      create_cookie
    end

    redirect_to(@playback_format.url, status: :temporary_redirect)
  end

  def resource
    @playback_format = PlaybackFormat
                       .joins(:recording)
                       .find_by!(format: params[:playback_format], recordings: { record_id: params[:record_id] })
    @recording = @playback_format.recording

    verify_cookie if Rails.configuration.x.protected_recordings_enabled && @recording.protected

    deliver_resource
  end

  private

  def create_cookie
    resource_path = "/#{@playback_format.format}/#{@recording.record_id}"
    expires = Time.now.to_i + Rails.configuration.x.recording_cookie_ttl
    payload = {
      'sub' => resource_path,
      'exp' => expires,
    }
    secret = Rails.application.secrets.secret_key_base
    token = JWT.encode(payload, secret, 'HS256')

    cookies[cookie_name] = {
      value: token,
      path: resource_path,
      secure: true,
      httponly: true,
      same_site: cookie_same_site_none(request.user_agent),
    }
  end

  def verify_cookie
    cookie = cookies[cookie_name]
    raise RecordingNotFoundError if cookie.blank?

    resource_path = "/#{@playback_format.format}/#{@recording.record_id}"
    secret = Rails.application.secrets.secret_key_base
    JWT.decode(
      cookie,
      secret,
      true,
      'sub' => resource_path,
      required_claims: %w[sub exp],
      verify_sub: true,
      algorithm: 'HS256'
    )
  rescue JWT::DecodeError
    raise RecordingNotFoundError
  end

  def cookie_name
    "recording_#{@playback_format.format}_#{@recording.record_id}"
  end

  def deliver_resource
    resource_path = request.original_fullpath
    static_resource_path = "/static-resource#{resource_path}"
    response.headers['X-Accel-Redirect'] = static_resource_path
    head(:ok)
  end

  def recording_not_found
    render "errors/recording_not_found", status: :not_found, formats: [:html]
  end
end
