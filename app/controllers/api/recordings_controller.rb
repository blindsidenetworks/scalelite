# frozen_string_literal: true

module Api
  class RecordingsController < ScaleliteApiController
    # "Authorization: Bearer <token>"; the scheme is case-insensitive (RFC 7235), the token may not
    # contain whitespace, commas or semicolons, and nothing may follow it.
    BEARER_TOKEN_PATTERN = /\ABearer ([^\s,;]+)\z/i

    # [REVIEW REQUIRED] Authentication: this controller does not use the loadbalancer checksum. Its
    # caller (a storage-expiry forwarder) holds only RECORDING_EXPIRED_SECRET, so the checksum is
    # replaced here, and only here, by verify_recording_expired_secret, which runs first and fails
    # closed.
    skip_before_action :verify_loadbalancer_checksum
    prepend_before_action :verify_recording_expired_secret

    # The base class raises UnsupportedContentType, which ApplicationController renders as BBB XML
    # with status 200. The caller treats 200 as success, so return a real error status instead.
    rescue_from BBBErrors::UnsupportedContentType do
      render json: { error: 'Content-Type must be application/json' }, status: :unsupported_media_type
    end

    # Mark a recording as deleted after its storage expired
    # POST /scalelite/api/expiredRecording
    #
    # Required header:
    # Authorization: Bearer <RECORDING_EXPIRED_SECRET>
    #
    # Expected params (JSON body):
    # { "id": String }  # record ID of the recording
    #
    # Responses:
    # 200 { "success": String }  marked as deleted, or already deleted
    # 400 { "error": String }    id missing, blank or not a string
    # 401 { "error": String }    secret missing, wrong, or not configured
    # 404 { "error": String }    no recording with that id
    # 415 { "error": String }    body is not JSON
    # 500 { "error": String }    unexpected error
    def expired_recording
      record_id = params[:id]
      return render json: { error: 'id must be a non-empty string' }, status: :bad_request unless record_id.is_a?(String) && record_id.present?

      recording = Recording.find_by(record_id:)
      return render json: { error: "Couldn't find recording id=#{record_id}" }, status: :not_found if recording.nil?

      # Lock so concurrent events for the same recording don't both delete it
      recording.with_lock do
        next if recording.state == 'deleted'

        recording.mark_delete!
        logger.info("Recording #{recording.record_id} expired, marked as deleted")
      end
      render json: { success: "Recording id=#{recording.record_id} was marked as deleted" }, status: :ok
    rescue StandardError => e
      logger.error("Failed to mark recording #{record_id.inspect} as deleted: #{e.class}: #{e.message}")
      render json: { error: "Couldn't mark recording id=#{record_id} as deleted" }, status: :internal_server_error
    end

    private

    # [REVIEW REQUIRED] Authentication for expiredRecording. Fails closed: a blank or unset
    # RECORDING_EXPIRED_SECRET rejects every request. The token is compared in constant time and is
    # never logged.
    def verify_recording_expired_secret
      secret = Rails.configuration.x.recording_expired_secret
      token = request.authorization.to_s[BEARER_TOKEN_PATTERN, 1]
      return if secret.present? && token.present? && ActiveSupport::SecurityUtils.secure_compare(token, secret)

      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
