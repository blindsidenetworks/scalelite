# frozen_string_literal: true

namespace :recordings do
  desc 'Watch for new recordings in the spool directory and import them'
  task :watch, [:force_polling, :latency] => :environment do |_t, args|
    args.with_defaults(latency: 30, force_polling: false)
    dir = Rails.configuration.x.recording_spool_dir
    FileUtils.mkdir_p(dir)

    # Setup AWS S3 Client if enabled (auto looks up the env variables it needs)
    client = Aws::S3::Client.new if ENV['S3_RECORDING']

    loop do
      Dir.glob("#{dir}/*.tar").each do |file|
        Rails.logger.debug { "Found #{file}" }
        RecordingImporter.import(file, client)
      rescue StandardError => e
        Rails.logger.error("Failed to import recording: #{e}")
        sleep(args.latency.to_f)
      end
      sleep(args.latency.to_f)
    end
  rescue SignalException => e
    Rails.logger.info("Exiting recording importer on signal: #{e}")
  end

  desc 'Search through the recordings and move unpublished recordings to the correct folder'
  task update: :environment do
    Recording.where(published: false).each do |recording|
      Rails.logger.debug { "Checking location of recording #{recording.record_id}" }
      # Check to make sure recording files are not already in the unpublished folder
      next unless Dir.glob(File.join(Rails.configuration.x.recording_unpublish_dir, '/*/', recording.record_id)).empty?

      Rails.logger.debug { "Starting move for recording #{recording.record_id}" }
      # Move recording files to correct directory
      recording.playback_formats.each do |playback|
        format_dir = File.join(Rails.configuration.x.recording_unpublish_dir, playback.format)
        FileUtils.mkdir_p(format_dir)
        FileUtils.mv(File.join(Rails.configuration.x.recording_publish_dir, playback.format, recording.record_id), format_dir)

        Rails.logger.debug { "Successfully moved format #{playback.format} for recording #{recording.record_id}" }
      rescue StandardError => e
        Rails.logger.error("Failed to move recording #{recording.record_id}: #{e}")
      end
    end
  end

  desc 'Associate any existing recordings with a tenant'
  task :addToTenant, [:tenant_id] => :environment do |_t, args|
    tenant_id = args[:tenant_id]
    unless tenant_id
      warn('No tenant ID was provided')
      exit(1)
    end

    Recording.all.each do |rec|
      next if rec.metadata.exists?(key: 'tenant-id')
      begin
        Metadatum.create!(recording_id: rec.id, key: 'tenant-id', value: tenant_id)
      rescue ActiveRecord::RecordInvalid => e
        warn("Error creating metadatum record for recording with id #{rec.id}: #{e}")
      end
    end

    puts("All existing recordings have been successfully linked to tenant #{tenant_id}")
  end
end
