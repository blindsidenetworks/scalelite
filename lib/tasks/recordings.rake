# frozen_string_literal: true

namespace :recordings do
  desc 'Watch for new recordings in the spool directory and import them'
  task :watch, [:force_polling, :latency] => :environment do |_t, args|
    args.with_defaults(latency: 60.seconds, force_polling: false)

    dir = Rails.configuration.x.recording_spool_dir
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
end
