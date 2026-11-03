# frozen_string_literal: true

namespace :recordings do
  desc 'Watch for new recordings in the spool directory and import them'
  task :watch, [:force_polling, :latency] => :environment do |_t, args|
    args.with_defaults(latency: 30, force_polling: false)
    dir = Rails.configuration.x.recording_spool_dir
    FileUtils.mkdir_p(dir)

    # Setup AWS S3 Client if enabled (auto looks up the env variables it needs)
    client = Aws::S3::Client.new if ENV['S3_RECORDING']

    # On SIGTERM/SIGINT only set a flag; the in-progress import is allowed to
    # finish before the loop exits, so a running extraction is never interrupted.
    shutdown = false
    %w[TERM INT].each do |sig|
      Signal.trap(sig) { shutdown = true }
    end

    loop do
      Dir.glob("#{dir}/*.tar").each do |file|
        break if shutdown
        Rails.logger.debug { "Found #{file}" }
        RecordingImporter.import(file, client)
      rescue StandardError => e
        Rails.logger.error("Failed to import recording: #{e}")
        sleep(args.latency.to_f)
      end
      break if shutdown
      sleep(args.latency.to_f)
    end
    Rails.logger.info('Exiting recording importer gracefully')
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

  desc 'Migrate existing S3 recording objects into per-tenant key prefixes'
  #   dry_run:       when 'true', preview without copying/deleting (default: false)
  #   delete_source: when 'true', also delete the source objects after copying (default: false)
  task :migrate_to_tenant_prefix, [:dry_run, :delete_source] => :environment do |_t, args|
    args.with_defaults(dry_run: 'false', delete_source: 'false')

    unless ENV['S3_RECORDING']
      warn('S3_RECORDING is not enabled; there is nothing to migrate')
      exit(1)
    end

    dry_run = args[:dry_run] == 'true'
    delete_source = args[:delete_source] == 'true'
    bucket = ENV.fetch('S3_BUCKET_NAME')
    s3 = Aws::S3::Client.new
    # A recording toggled published/unpublished may have left objects under either prefix.
    states = %w[published unpublished].freeze
    # copy_source must be URL-encoded per path segment (slashes preserved).
    encode_source = ->(key) { key.split('/').map { |seg| ERB::Util.url_encode(seg) }.join('/') }

    copied = 0
    skipped = 0

    Recording.where.not(state: 'deleted').find_each do |rec|
      tenant_name = rec.tenant&.name
      if tenant_name.blank?
        skipped += 1
        next
      end

      rec.playback_formats.each do |playback_format|
        states.each do |state|
          source_prefix = "#{state}/#{playback_format.format}/#{rec.record_id}/"
          continuation = nil

          loop do
            resp = s3.list_objects_v2(bucket: bucket, prefix: source_prefix, continuation_token: continuation)
            resp.contents.each do |object|
              dest_key = "#{tenant_name}/#{object.key}"
              if dry_run
                puts("[dry-run] #{object.key} -> #{dest_key}")
              else
                s3.copy_object(bucket: bucket, copy_source: "#{bucket}/#{encode_source.call(object.key)}", key: dest_key)
                s3.delete_object(bucket: bucket, key: object.key) if delete_source
              end
              copied += 1
            end

            break unless resp.is_truncated
            continuation = resp.next_continuation_token
          end
        end
      end
    end

    puts("#{copied} object(s); skipped #{skipped} recording(s) without a tenant.")
  end
end
