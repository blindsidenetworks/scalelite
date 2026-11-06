# frozen_string_literal: true

module Api
  class RecordingsController < ScaleliteApiController
    # TODO: Authenticate requests
    skip_before_action :verify_loadbalancer_checksum

    # Mark a recording as deleted after its storage expired
    # POST /scalelite/api/expiredRecording
    #
    # Expected params:
    # { "id": String }
    #
    # Successful response:
    # { "success": String }
    def expired_recording
      record_id = nil # TODO: Parse the event to get the recording id

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
  end
end
