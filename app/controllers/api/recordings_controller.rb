# frozen_string_literal: true

module Api
  class RecordingsController < ScaleliteApiController
    # "Authorization: Bearer <token>"; the scheme is case-insensitive (RFC 7235), the token may not
    # contain whitespace, commas or semicolons, and nothing may follow it.
    BEARER_TOKEN_PATTERN = /\ABearer ([^\s,;]+)\z/i

    # [REVIEW REQUIRED] Authentication: this controller does not use the loadbalancer checksum. Its
    # caller (a storage-expiry forwarder) holds only RECORDING_EXPIRED_SECRET, so the checksum is
    # replaced here, and only here, by verify_recording_expired_token, which fails closed.
    skip_before_action :verify_loadbalancer_checksum
    before_action :verify_recording_expired_token

    # Mark a recording as deleted after its storage expired
    # POST /scalelite/api/expiredRecording
    #
    # Required header:
    # Authorization: Bearer <JWT signed with RECORDING_EXPIRED_SECRET (HS512), claims record_id and exp>
    #
    # Successful response:
    # { "success": String }
    def expired_recording
      recording = Recording.find_by(record_id: @record_id)
      return render json: { error: "Couldn't find recording id=#{@record_id}" }, status: :not_found if recording.nil?

      # Lock so concurrent events for the same recording don't both delete it
      recording.with_lock do
        next if recording.state == 'deleted'

        recording.mark_delete!
        logger.info("Recording #{recording.record_id} expired, marked as deleted")
      end
      render json: { success: "Recording id=#{recording.record_id} was marked as deleted" }, status: :ok
    rescue StandardError => e
      logger.error("Failed to mark recording #{@record_id.inspect} as deleted: #{e.class}: #{e.message}")
      render json: { error: "Couldn't mark recording id=#{@record_id} as deleted" }, status: :internal_server_error
    end

    private

    # [REVIEW REQUIRED] Authentication for expiredRecording. The caller signs a short-lived JWT naming
    # the recording, so the secret itself is never sent. Fails closed: a blank or unset
    # RECORDING_EXPIRED_SECRET, or any token that is missing, unsigned, signed with another key or
    # algorithm, expired, or lacks a string record_id, is rejected. The token is never logged.
    def verify_recording_expired_token
      secret = Rails.configuration.x.recording_expired_secret
      token = request.authorization.to_s[BEARER_TOKEN_PATTERN, 1]
      return render_unauthorized if secret.blank? || token.blank?

      payload, = JWT.decode(token, secret, true, algorithm: 'HS512', required_claims: %w[exp record_id])
      record_id = payload['record_id']
      return render_unauthorized unless record_id.is_a?(String) && record_id.present?

      @record_id = record_id
    rescue JWT::DecodeError
      render_unauthorized
    end

    def render_unauthorized
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end
end
