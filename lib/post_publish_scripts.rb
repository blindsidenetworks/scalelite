# frozen_string_literal: true

class PostPublishScripts
  def self.run(recording_id)
    wait_time = Rails.configuration.x.recording_ready_notifier_time.minutes
    RecordingReadyNotifierJob.set(wait: wait_time)
                             .perform_later(recording_id)
  end
end
