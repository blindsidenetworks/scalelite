# frozen_string_literal: true

def check_multitenancy
  abort 'Multitenancy is disabled, task can not be completed' unless ENV['MULTITENANCY_ENABLED']
end

desc 'List all the Tenants'
task tenants: :environment do |_t, _args|
  check_multitenancy
  tenants = Tenant.all
  host_name = Rails.configuration.x.url_host
  api_mate_url = Rails.configuration.x.api_mate_url

  if tenants.present?
    tenants.each do |tenant|
      puts("id: #{tenant.id}")
      puts("\tname: #{tenant.name}")
      puts("\tsecrets: #{tenant.secrets}")
      if api_mate_url.present?
        puts("\tapi_mate: #{api_mate_url}?server=https://#{tenant.name}.#{host_name}/bigbluebutton/api/&secret=#{tenant.secrets_array[0]}")
      end
      recording_dir = tenant_recording_dir_line(tenant)
      puts("\trecording dir: #{recording_dir}") if recording_dir.present?
      puts("\tlrs_endpoint: #{tenant.lrs_endpoint}") if tenant.lrs_endpoint.present?
      puts("\tlrs_username: #{tenant.lrs_username}") if tenant.lrs_username.present?
      puts("\tlrs_password: #{tenant.lrs_password}") if tenant.lrs_password.present?
      puts("\tkc_token_url: #{tenant.kc_token_url}") if tenant.kc_token_url.present?
      puts("\tkc_client_id: #{tenant.kc_client_id}") if tenant.kc_client_id.present?
      puts("\tkc_client_secret: #{tenant.kc_client_secret}") if tenant.kc_client_secret.present?
      puts("\tkc_username: #{tenant.kc_username}") if tenant.kc_username.present?
      puts("\tkc_password: #{tenant.kc_password}") if tenant.kc_password.present?
    end
  end

  puts "Total number of tenants: #{tenants.size}"
end

# The directory a tenant was given for its recordings, as one line. See docs/recording-directories.md.
#
# @param [Tenant] tenant
# @return [String, nil] nil for a tenant without one, whose recordings are where all recordings are, so that
#   it is listed as it always was.
def tenant_recording_dir_line(tenant)
  return nil if tenant.recording_dir.blank?
  return tenant.recording_dir if RecordingDirectoryService.enabled?

  "#{tenant.recording_dir} (not in use, RECORDING_DIR_PER_TENANT is off)"
end

# Why a directory cannot be given to a tenant, as the container the task runs in sees it. Scalelite never
# creates the directory, and with one that is not there the recordings of the tenant are no longer imported.
#
# @param [String] dir
# @return [String, nil] what is wrong with it, nil for a directory that can be used.
def recording_dir_problem(dir)
  if !File.exist?(dir)
    # The usual reason is a path as the host has it: the task runs in a container, which has the recordings
    # under a path of its own. Or a volume that is not mounted into this container.
    "#{dir} does not exist inside this container. Scalelite does not create it: create it on the host, on a volume " \
      'the containers have, and give the path as the containers see it. This one has the recordings below ' \
      "#{File.dirname(RecordingDirectoryService.shared_roots.first)}."
  elsif !File.directory?(dir)
    "#{dir} exists inside this container, but is not a directory."
  elsif !File.writable?(dir)
    "#{dir} is not writable for the user this task runs as (UID #{Process.uid}). Hand it to that user on the host, " \
      "as in: chown #{Process.uid} <directory>"
  end
end

# Move the unpublished recordings out of the directory a tenant had before, to where they belong now. A
# published recording there is found through its link whatever directory that leads to, and is moved by
# rake recordings:relocate. An unpublished one has no link: left in a directory the tenant no longer has,
# nothing would find it again, neither to publish it nor to delete it. See docs/recording-directories.md.
#
# Nothing is removed. What cannot be moved is left where it is and named, with what to do about it.
#
# @param [Tenant] tenant with the directory it has from now on, saved.
# @param [String] previous the directory it had before.
def move_unpublished_out(tenant, previous)
  source_root = File.join(previous, 'unpublished')
  target_root = RecordingDirectoryService.roots(tenant).last

  unless File.directory?(previous)
    warn("WARNING: #{previous}, the directory the tenant had before, is not there, so its unpublished recordings " \
         "could not be moved. Once it is mounted again, move #{source_root}/<format>/<record id> to " \
         "#{target_root}/<format>/<record id> by hand: nothing else finds them, neither to publish nor to delete them.")
    return
  end
  return unless File.directory?(source_root)

  # A directory Scalelite looks in anyway loses nothing, and holds the recordings of everybody else besides
  known = RecordingDirectoryService.shared_roots + Array(RecordingDirectoryService.tenant_roots(tenant))
  return if known.any? { |root| File.identical?(root, source_root) }

  moved = 0
  left = 0
  Dir.glob(File.join(source_root, '*', '*')).each do |source|
    next unless File.directory?(source)

    format = File.basename(File.dirname(source))
    record_id = File.basename(source)
    recording = Recording.includes(:metadata).find_by(record_id: record_id)
    reason = if recording.nil?
               'is not known to Scalelite and was left where it is'
             elsif recording.state == 'deleted'
               'belongs to a recording that was deleted in Scalelite and was left where it is: remove it by hand'
             elsif recording.metadata.find { |metadatum| metadatum.key == 'tenant-id' }&.value != tenant.id
               "is not a recording of tenant #{tenant.name} and was left where it is"
             end
    if reason
      left += 1
      warn("WARNING: #{source} #{reason}")
      next
    end

    # Locked like publishRecordings locks it, so that a recording is not moved by both at once
    status, dirs = recording.with_lock do
      RecordingDirectoryService.new(recording, tenant: tenant).adopt(source, format)
    end
    case status
    when :moved
      moved += 1
      puts("#{dirs.first} -> #{dirs.last}")
    when :scattered
      left += 1
      warn("WARNING: #{source} was left where it is: the recording has its #{format} files in " \
           "#{dirs.drop(1).join(', ')} as well, and nothing can tell which copy is the good one")
    end
  rescue StandardError => e
    left += 1
    warn("ERROR: #{source} could not be moved: #{e.message}. Move it to #{target_root}/#{format}/#{record_id} by hand.")
  end

  puts("#{moved} unpublished playback formats moved out of #{source_root}") if moved.positive?
  warn("WARNING: #{left} unpublished playback formats are left in #{source_root}, see above") if left.positive?
end

namespace :tenants do
  desc 'Add a new Tenant'
  task :add, [:name, :secrets] => :environment do |_t, args|
    check_multitenancy
    name = args[:name]
    secrets = args[:secrets]

    unless name.present? && secrets.present?
      warn('Error: both name and secrets are required to create a Tenant')
      exit(1)
    end

    tenant = Tenant.create!(name: name, secrets: secrets)

    puts('OK')
    puts("New Tenant id: #{tenant.id}")
  end

  desc 'Update an existing Tenant'
  task :update, [:id, :name, :secrets] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]
    name = args[:name]
    secrets = args[:secrets]

    if id.blank? || !(name.present? || secrets.present?)
      warn('Error: id and either name or secrets are required to update a Tenant')
      exit(1)
    end

    tenant = Tenant.find(id)
    tenant.name = name if name.present?
    tenant.secrets = secrets if secrets.present?

    tenant.save!

    puts('OK')
    puts("Updated Tenant id: #{tenant.id}")
  end

  desc 'Give a Tenant a directory of its own for its recordings'
  task :recording_dir, [:id, :dir] => :environment do |_t, args|
    check_multitenancy

    if args[:id].blank?
      warn('Error: id is required to set the recording directory of a Tenant')
      exit(1)
    end

    tenant = Tenant.find(args[:id])
    previous = tenant.recording_dir
    # An empty value takes the directory away again, back to where all recordings are kept
    begin
      dir = Tenant.parse_recording_dir(args[:dir])
    rescue ArgumentError => e
      warn("ERROR: #{e.message}")
      exit(1)
    end

    problem = recording_dir_problem(dir) if dir.present?
    if problem
      warn("ERROR: #{problem}")
      exit(1)
    end

    # What is moved and what is left is printed on both outputs, and read in the order it happened
    $stdout.sync = true
    # Saved before anything is moved: a recording moved into a directory the tenant then did not get would be
    # the one that is lost
    tenant.recording_dir = dir
    tenant.save!

    puts('OK')
    puts("recording dir: #{tenant_recording_dir_line(tenant) || 'none'}")

    if dir.present? && !"#{dir}/".start_with?("#{RecordingDirectoryService.shared_roots.first}/")
      # Whether the web server sees the directory cannot be found out from here, and a recording it does not
      # see answers 404. It usually has the publish directory alone, so a directory next to it is not enough.
      puts("The web server container needs #{dir}/published under the same path, or playback answers 404.")
    end
    move_unpublished_out(tenant, previous) if previous.present? && previous != dir
    puts("Move existing recordings with: rake recordings:relocate[#{tenant.id}]")
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No tenant found with id: #{args[:id]}")
    exit(1)
  end

  desc 'Update an existing Tenants LRS credentials with basic authentication'
  task :update_lrs_basic, [:id, :lrs_endpoint, :lrs_username, :lrs_password] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]
    lrs_endpoint = args[:lrs_endpoint]
    lrs_username = args[:lrs_username]
    lrs_password = args[:lrs_password]

    if id.blank? || lrs_endpoint.blank? || lrs_username.blank? || lrs_password.blank?
      warn('Error: id, LRS_ENDPOINT, LRS_USERNAME, LRS_PASSWORD are required to update a Tenant')
      exit(1)
    end

    tenant = Tenant.find(id)
    tenant.lrs_endpoint = lrs_endpoint
    tenant.lrs_username = lrs_username
    tenant.lrs_password = lrs_password

    tenant.save!

    puts('OK')
    puts("Updated Tenant id: #{tenant.id}")
  end

  desc 'Update an existing Tenants LRS credentials with Keycloak'
  task :update_lrs_kc, [:id, :lrs_endpoint, :kc_token_url, :kc_client_id, :kc_client_secret, :kc_username, :kc_password] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]
    lrs_endpoint = args[:lrs_endpoint]
    kc_token_url = args[:kc_token_url]
    kc_client_id = args[:kc_client_id]
    kc_client_secret = args[:kc_client_secret]
    kc_username = args[:kc_username]
    kc_password = args[:kc_password]

    if id.blank? || lrs_endpoint.blank? || kc_token_url.blank? || kc_client_id.blank? ||
       kc_client_secret.blank? || kc_username.blank? || kc_password.blank?
      warn('Error: LRS_ENDPOINT, KC_TOKEN_URL, KC_CLIENT_ID, KC_CLIENT_SECRET, KC_USERNAME, KC_PASSWORD are required to update a Tenant')
      exit(1)
    end

    tenant = Tenant.find(id)
    tenant.lrs_endpoint = lrs_endpoint
    tenant.kc_token_url = kc_token_url
    tenant.kc_client_id = kc_client_id
    tenant.kc_client_secret = kc_client_secret
    tenant.kc_username = kc_username
    tenant.kc_password = kc_password

    tenant.save!

    puts('OK')
    puts("Updated Tenant id: #{tenant.id}")
  end

  desc 'Remove existing Tenant'
  task :remove, [:id] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]

    tenant = Tenant.find(id)
    if tenant.blank?
      warn("Tenant with id #{id} does not exist in the system. Exiting...")
      exit(1)
    end

    if tenant.destroy!
      # Should there be a puts("OK") here?
      puts('Tenant was successfully deleted.')
    else
      warn('Error! Tenant has not been deleted')
      # Should there be an exit(1) here?
    end
  end
end
