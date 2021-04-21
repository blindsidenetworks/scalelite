# frozen_string_literal: true

class PostPublishScripts
  def self.run(recording_id)
    RecordingReadyNotifierJob.perform_later(recording_id)
  end
end
