# frozen_string_literal: true

namespace :recordings do
  desc 'Watch for new recordings in the spool directory and import them'
  task :watch, [:force_polling, :latency] => :environment do |_t, args|
    args.with_defaults(latency: 60.seconds, force_polling: false)

    dir = Rails.configuration.x.recording_spool_dir
    FileUtils.mkdir_p(dir)
    opts = {
      latency: args.latency.to_f,
      force_polling: ActiveModel::Type::Boolean.new.cast(args.force_polling),
    }
    Rails.logger.info("Monitoring #{dir} for new recording files")
    listener = Listen.to(dir, opts) do |_modified, added, _removed|
      added.each do |file|
        RecordingImporter.import(file)
      rescue StandardError => e
        Rails.logger.error("Failed to import recording: #{e}")
        Rails.logger.warn(e.full_message(highlight: false, order: :top))
      end
    end
    listener.only(/\.tar$/)

    Rails.logger.debug('Checking for existing files…')
    Dir.glob("#{dir}/*.tar").each do |file|
      RecordingImporter.import(file)
    rescue StandardError => e
      Rails.logger.error("Failed to import recording: #{e}")
    end
    Rails.logger.debug('Starting file monitor…')
    listener.start
    sleep
  rescue SignalException => e
    Rails.logger.info("Exiting recording importer on signal: #{e}")
  end

  desc 'Search through the recordings and move unpublished recordings to the correct folder'
  task update: :environment do
    Recording.where(published: false).each do |recording|
      Rails.logger.debug("Checking location of recording #{recording.record_id}")
      # Check to make sure recording files are not already in the unpublished folder
      next unless Dir.glob(File.join(Rails.configuration.x.recording_unpublish_dir, '/*/', recording.record_id)).empty?

      Rails.logger.debug("Starting move for recording #{recording.record_id}")
      # Move recording files to correct directory
      recording.playback_formats.each do |playback|
        format_dir = File.join(Rails.configuration.x.recording_unpublish_dir, playback.format)
        FileUtils.mkdir_p(format_dir)
        FileUtils.mv(File.join(Rails.configuration.x.recording_publish_dir, playback.format, recording.record_id), format_dir)

        Rails.logger.debug("Successfully moved format #{playback.format} for recording #{recording.record_id}")
      rescue StandardError => e
        Rails.logger.error("Failed to move recording #{recording.record_id}: #{e}")
      end
    end
  end
end
