# frozen_string_literal: true

class PostImporterScripts
  def self.run(recording_id)
    RecordingReadyNotifierService.execute(recording_id)
  end
end
