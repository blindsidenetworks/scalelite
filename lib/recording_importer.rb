# frozen_string_literal: true

class RecordingImporter
  class RecordingImporterError < StandardError
  end

  def self.logger
    Rails.logger
  end

  def self.import(filename)
    return if Rails.configuration.x.recording_disabled

    logger.info("Importing recording from file: #{filename}")

    recording = nil

    Dir.mktmpdir(Rails.configuration.x.recording_work_dir) do |tmpdir|
      FileUtils.cd(tmpdir) do
        system('tar', '--verbose', '--extract', '--file', filename) \
          || raise(RecordingImporterError, "Failed to extract tar file: #{filename}")

        Dir.glob('*/*/metadata.xml').each do |metadata_xml|
          logger.info("Found metadata file: #{metadata_xml}")
          metadata = IO.read(metadata_xml)
          recording, playback_format = Recording.create_from_metadata_xml(metadata, published: false)

          publish_format_dir = "#{Rails.configuration.x.recording_publish_dir}/#{playback_format.format}"
          FileUtils.mkdir_p(publish_format_dir)
          FileUtils.mv("#{playback_format.format}/#{recording.record_id}", publish_format_dir, force: true)
        end

        recording.update!(published: true)
      end
    end

    FileUtils.rm(filename)
  end
end
