# frozen_string_literal: true

class RecordingImporter
  class RecordingImporterError < StandardError
  end

  def self.logger
    Rails.logger
  end

  def self.import(filename, aws_client = nil)
    return if Rails.configuration.x.recording_disabled

    logger.info("Importing recording from file: #{filename}")

    recording = nil
    retry_attempts = 0
    recording_import_unpublished = Rails.configuration.x.recording_import_unpublished

    Dir.mktmpdir(nil, Rails.configuration.x.recording_work_dir) do |tmpdir|
      FileUtils.cd(tmpdir) do
        # rubocop:disable Style/RedundantLineContinuation
        system('tar', '--verbose', '--extract', '--file', filename) \
          || raise(RecordingImporterError, "Failed to extract tar file: #{filename}")
        # rubocop:enable Style/RedundantLineContinuation
        Dir.glob('*/*/metadata.xml').each do |metadata_xml|
          Recording.transaction do
            logger.info("Found metadata file: #{metadata_xml}")
            metadata = File.read(metadata_xml)
            recording, playback_format = Recording.create_from_metadata_xml(metadata)
            next if recording.nil?

            published_status = if recording.publish_updated
                                 recording.published
                               elsif recording_import_unpublished
                                 false
                               elsif !recording.published
                                 false
                               else
                                 true
                               end

            protected = Rails.configuration.x.protected_recordings_enabled
            recording.update!(published: published_status, protected: protected)
            directory = "#{playback_format.format}/#{recording.record_id}"

            if ENV['S3_RECORDING'] # Store recordings in S3
              key = published_status ? 'published/' : 'unpublished/'

              files = Dir.glob("#{directory}/**/*").select { |f| File.file?(f) }
              files.each do |file|
                content_type = Rack::Mime.mime_type(File.extname(file), "application/octet-stream")
                content_disposition = %w[.pdf .ogg].include?(File.extname(file)) ? "attachment" : nil

                object = Aws::S3::Object.new(ENV.fetch('S3_BUCKET_NAME'), "#{key}#{file}", client: aws_client)
                object.upload_file(file, content_type: content_type, content_disposition: content_disposition)
              end

              FileUtils.rm_rf(directory)
            else
              publish_format_dir = "#{Rails.configuration.x.recording_publish_dir}/#{playback_format.format}"
              unpublish_format_dir = "#{Rails.configuration.x.recording_unpublish_dir}/#{playback_format.format}"

              format_dir = published_status ? publish_format_dir : unpublish_format_dir

              FileUtils.rm_rf("#{publish_format_dir}/#{recording.record_id}")
              FileUtils.rm_rf("#{unpublish_format_dir}/#{recording.record_id}")

              FileUtils.mkdir_p(format_dir)
              FileUtils.mv(directory, format_dir, force: true)
            end
          end
        end
        callback_data = CallbackData.find_by(meeting_id: recording.meeting_id)
        callback_data&.update(recording_id: recording.id)
      end
    end

    FileUtils.rm(filename)
    PostImporterScripts.run(recording.id)
  rescue ActiveRecord::StatementInvalid
    ActiveRecord::Base.establish_connection
    retry_attempts += 1
    retry if retry_attempts <= Rails.configuration.x.db_connection_retry_count
  end
end
