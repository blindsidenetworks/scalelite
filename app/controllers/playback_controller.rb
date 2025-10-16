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
    secret = Rails.configuration.secrets.secret_key_base
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
    secret = Rails.configuration.secrets.secret_key_base
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
    if ENV["CLOUDFRONT_URL"].present? && request.format.html?
      set_cf_signed_cookies!(format: @playback_format.format, record_id: @recording.record_id, published: @recording.published?)

      prefix = @recording.published? ? "published" : "unpublished"
      page   = "index.html"
      cf_url = "#{ENV.fetch("CLOUDFRONT_URL")}/#{prefix}/#{@playback_format.format}/#{@recording.record_id}/#{page}"

      redirect_to cf_url, allow_other_host: true, status: :temporary_redirect
    else
      resource_path = request.original_fullpath
      static_resource_path = "/static-resource#{resource_path}"
      response.headers['X-Accel-Redirect'] = static_resource_path
      response.headers['Content-Disposition'] = "attachment" unless %w[presentation video screenshare].include?(@playback_format.format)
      head(:ok)
    end
  end

  def recording_not_found
    render "errors/recording_not_found", status: :not_found, formats: [:html]
  end

  private
  def set_cf_signed_cookies!(format:, record_id:, published:, ttl: 5.minutes)
    base_prefix = published ? "published" : "unpublished"
    path_scope  = "/#{base_prefix}/#{format}/#{record_id}/*"

    cf_origin   = ENV.fetch("CLOUDFRONT_URL")

    pem = Base64.decode64(ENV["CF_PRIVATE_KEY_B64"])

    signer = Aws::CloudFront::CookieSigner.new(
      key_pair_id: ENV.fetch("CF_KEY_PAIR_ID"),
      private_key: OpenSSL::PKey::RSA.new(pem)
    )

    expires_at = Time.now + (ttl.is_a?(Numeric) ? ttl : ttl.to_i)
    cf_cookies = signer.signed_cookie("#{cf_origin}#{path_scope}", expires: expires_at.to_i)


    parent_domain = ".#{request.domain}"

    cookie_opts = {
      domain: parent_domain,
      path:   "/",
      secure: true,
      httponly: true,
      same_site: :none,
      expires: expires_at
    }

    cf_cookies.each { |name, value| cookies[name] = cookie_opts.merge(value: value) }
  end
end
