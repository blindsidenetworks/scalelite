# frozen_string_literal: true

# Go through the recordings once and put every playback format where it belongs, or only work out what that
# would take. See RecordingDirectoryService#relocate.
#
# @param [ActiveRecord::Relation] recordings the recordings to go through, with their metadata.
# @param [Hash{String => Tenant}] tenants every tenant by its ID, read once: the tenant of a recording is
#   otherwise a query and a Redis call for every one of them.
# @param [Boolean] dry_run move nothing, for the pass that works out what there is to confirm.
# @param [Boolean] report print every move and every recording that was left alone. Off for that same pass.
# @yield [status, dirs] what RecordingDirectoryService#relocate returned for one playback format.
# @return [Hash{Symbol => Integer}] the playback formats by what happened to them, the +:failed+ ones included.
def relocate_recordings(recordings, tenants, dry_run:, report: true)
  counts = Hash.new(0)

  recordings.find_each do |recording|
    # A deleted recording has neither formats nor files left
    next if recording.state == 'deleted'

    tenant = tenants[recording.metadata.find { |metadatum| metadatum.key == 'tenant-id' }&.value]
    directories = RecordingDirectoryService.new(recording, tenant: tenant)

    # Locked like publishRecordings locks it, so that a recording is not moved by both at once
    recording.with_lock do
      recording.playback_formats.each do |playback_format|
        status, dirs = directories.relocate(playback_format.format, dry_run: dry_run)
        counts[status] += 1
        yield(status, dirs) if block_given?
        next unless report

        case status
        when :moved then puts("#{dirs.first} -> #{dirs.last}")
        when :scattered then warn("WARNING: #{recording.record_id} #{playback_format.format} is in more than one place " \
                                  "and was left alone: #{dirs.join(', ')}")
        end
      rescue StandardError => e
        counts[:failed] += 1
        warn("ERROR: #{recording.record_id} #{playback_format.format} could not be moved: #{e.message}") if report
      end
    end
  end

  counts
end

# Ask before anything is moved, with what it is about: how many playback formats, and from which directory
# into which. Whatever is not a clear yes is a no, the end of the input included, so that a run without a
# terminal moves nothing unless it was sent a "y". Answering no is also how to only look at what would happen.
#
# @param [Hash{Symbol => Integer}] planned what the pass that moves nothing counted.
# @param [Tenant, nil] tenant the tenant the run is limited to.
# @param [Array<Array(String, String)>] moves from where to where each playback format would be moved.
# @param [Array<String>] linked the directories outside the publish directory that published recordings would
#   be moved into, see {#relocate_linked_directories}.
# @return [Boolean] whether the answer was yes.
def relocate_confirmed?(planned, tenant, moves, linked)
  # The question has to be on the screen before the answer is waited for
  $stdout.sync = true
  puts("#{planned[:moved]} playback formats#{" of tenant #{tenant.name}" if tenant} will be moved and " \
       "#{planned[:relinked]} linked again.")
  # By directory, not one line for each recording: this is read before a question, and every move is
  # printed once more when it is made
  moves.map { |from, to| [File.dirname(from, 2), File.dirname(to, 2)] }.tally.sort.each do |(from, to), count|
    puts("\t#{count} from #{from} to #{to}")
  end
  if linked.any?
    # This container sees the directory, or nothing would be moved into it. Whether the web server does is
    # the one thing that cannot be found out from here, and the one that turns every moved recording into
    # a 404 when it does not.
    puts('WARNING: the web server container must see these directories under the same path, or the recordings ' \
         'answer 404:')
    linked.each { |dir| puts("\t#{dir}") }
  end
  puts('Continue? [y/N]')
  $stdin.gets.to_s.strip.match?(/\Ay(es)?\z/i)
end

# The directories of tenants that published recordings are about to be moved into and that do not lie inside
# the publish directory. A recording there is reached through a link that carries the full path, so the web
# server has to have that path as well; inside the publish directory the link is relative and it always does.
#
# @param [Array<String>] targets where the playback formats would be moved to.
# @param [Array<Tenant>] tenants
# @return [Array<String>] the +published+ directory of every tenant directory that is concerned.
def relocate_linked_directories(targets, tenants)
  publish_dir = RecordingDirectoryService.shared_roots.first
  tenants.filter_map { |tenant| RecordingDirectoryService.tenant_roots(tenant)&.first }.uniq.sort.select do |dir|
    !"#{dir}/".start_with?("#{publish_dir}/") && targets.any? { |target| target.start_with?("#{dir}/") }
  end
end

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
      # The unpublished folder inside the directory the tenant was given where RECORDING_DIR_PER_TENANT is
      # set; files that are there already stay as they are
      directories = RecordingDirectoryService.new(recording)

      # Move recording files to correct directory
      recording.playback_formats.each do |playback|
        directories.place(playback.format, published: false)

        Rails.logger.debug { "Successfully moved format #{playback.format} for recording #{recording.record_id}" }
      rescue StandardError => e
        Rails.logger.error("Failed to move recording #{recording.record_id}: #{e}")
      end
    end
  end

  desc 'Move the recordings to the directories they belong in, after the directory of a tenant or RECORDING_DIR_PER_TENANT changed'
  #   tenant_id: only the recordings of this tenant (default: every recording)
  task :relocate, [:tenant_id] => :environment do |_t, args|
    if ENV['S3_RECORDING']
      warn('Recordings are kept in S3 (S3_RECORDING), not in directories; there is nothing to relocate')
      exit(1)
    end

    # One argument and no more. A call with an empty first one, "[,<tenant-id>]", would otherwise be read as
    # no tenant at all and offer to move the recordings of everybody.
    if args.extras.any?
      warn('ERROR: rake recordings:relocate takes the ID of a tenant and nothing else, as in recordings:relocate[<tenant-id>]')
      exit(1)
    end

    tenants = Tenant.all.index_by(&:id)
    recordings = Recording.includes(:metadata)

    if args[:tenant_id].present?
      # A mistyped ID would otherwise look like a tenant that has nothing to move
      unless tenants.key?(args[:tenant_id])
        warn("ERROR: No tenant found with id: #{args[:tenant_id]}")
        exit(1)
      end
      recordings = recordings.where(id: Metadatum.where(key: 'tenant-id', value: args[:tenant_id]).select(:recording_id))
    end

    # Off, the directories of tenants are not used, and their recordings belong where all recordings are. Said,
    # since that is also what a setting that was forgotten looks like: everything is in place already.
    unless RecordingDirectoryService.enabled?
      concerned = (args[:tenant_id].present? ? [tenants[args[:tenant_id]]] : tenants.values).select { |t| t.recording_dir.present? }
      if concerned.any?
        whose = concerned.one? ? "tenant #{concerned.first.name}" : "#{concerned.size} tenants"
        puts("NOTE: RECORDING_DIR_PER_TENANT is off, so the directories given to tenants are not used: the recordings of #{whose} " \
             "belong in #{RecordingDirectoryService.shared_roots.join(' and ')}.")
      end
    end

    # Worked out first, so that the question names what is about to happen. Nothing to move, nothing to ask.
    moves = []
    planned = relocate_recordings(recordings, tenants, dry_run: true, report: false) do |status, dirs|
      moves << dirs if status == :moved
    end
    linked = relocate_linked_directories(moves.map(&:last), tenants.values)
    if (planned[:moved] + planned[:relinked]).positive? && !relocate_confirmed?(planned, tenants[args[:tenant_id]], moves, linked)
      puts('Nothing was moved.')
      exit(1)
    end

    counts = relocate_recordings(recordings, tenants, dry_run: false)

    puts("#{counts[:moved]} playback formats moved, #{counts[:relinked]} linked again, " \
         "#{counts[:in_place]} already in place, #{counts[:missing]} not found, " \
         "#{counts[:scattered]} in more than one place, #{counts[:failed]} failed")
    if counts[:missing].positive? && counts.except(:missing).values.sum.zero?
      warn('WARNING: not one recording was found. Are the recordings mounted where this task runs ' \
           "(#{Rails.configuration.x.recording_publish_dir})?")
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
