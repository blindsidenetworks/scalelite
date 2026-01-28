# frozen_string_literal: true

desc('List configured BigBlueButton servers')
task servers: :environment do
  servers = Server.all
  warn('No servers are configured') if servers.empty?
  servers.each do |server|
    puts("id: #{server.id}")
    puts("\turl: #{server.url}")
    puts("\tsecret: #{server.secret}")
    if server.state.present?
      puts("\t#{server.state}")
    else
      puts("\t#{server.enabled ? 'enabled' : 'disabled'}")
    end
    puts("\tload: #{server.load.presence || 'unavailable'}")
    puts("\tload multiplier: #{server.load_multiplier.nil? ? 1.0 : server.load_multiplier.to_d}")
    puts("\tbbb version: #{server.bbb_version.nil? ? '' : server.bbb_version}")
    puts("\ttag: #{server.tag.nil? ? '' : server.tag}")
    puts("\t#{server.online ? 'online' : 'offline'}")
  end
end

namespace :servers do
  desc 'Add a new BigBlueButton server (it will be added disabled)'
  task :add, [:url, :secret, :load_multiplier, :tag] => :environment do |_t, args|
    if args.url.nil? || args.secret.nil?
      warn('Error: Please input at least a URL and a secret!')
      exit(1)
    end

    unless args.url.start_with?('http://', 'https://')
      warn('Error: Server URL must start with http:// or https://')
      exit(1)
    end

    Rails.logger.info("Adding server #{args.url}...")

    tmp_load_multiplier = 1.0
    unless args.load_multiplier.nil?
      tmp_load_multiplier = args.load_multiplier.to_d
      if tmp_load_multiplier.zero?
        Rails.logger.info('WARNING! Load-multiplier was not readable or 0, so it is now 1')
        tmp_load_multiplier = 1.0
      end
    end
    server = Server.create!(url: args.url, secret: args.secret, load_multiplier: tmp_load_multiplier, tag: args.tag.presence)
    puts('OK')
    puts("id: #{server.id}")
  end

  desc 'Update a BigBlueButton server'
  task :update, [:id, :secret, :load_multiplier, :tag] => :environment do |_t, args|
    Rails.logger.info("Updating server #{args.id}...")
    server = Server.find(args.id)
    server.secret = args.secret unless args.secret.nil?
    tmp_load_multiplier = server.load_multiplier
    unless args.load_multiplier.nil?
      tmp_load_multiplier = args.load_multiplier.to_d
      if tmp_load_multiplier.zero?
        Rails.logger.info('WARNING! Load-multiplier was not readable or 0, so it is now 1')
        tmp_load_multiplier = 1.0
      end
    end
    server.load_multiplier = tmp_load_multiplier
    server.tag = args.tag.presence unless args.tag.nil?
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  end

  desc 'Remove a BigBlueButton server'
  task :remove, [:id] => :environment do |_t, args|
    Rails.logger.info("Removing server #{args.id}...")
    server = Server.find(args.id)
    server.destroy!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  end

  desc 'Mark a BigBlueButton server as available for scheduling new meetings'
  task :enable, [:id] => :environment do |_t, args|
    Rails.logger.info("Enabling server #{args.id}...")
    server = Server.find(args.id)
    server.state = 'enabled'
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  end

  desc 'Mark a BigBlueButton server as cordoned to stop scheduling new meetings but consider for
        load calculation and joining existing meetings'
  task :cordon, [:id] => :environment do |_t, args|
    Rails.logger.info("Cordoning server #{args.id}...")
    server = Server.find(args.id)
    server.state = 'cordoned'
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  rescue StandardError => e
    warn("ERROR: Failed to cordon server #{args.id} - #{e}")
    exit(1)
  end

  desc 'Mark a BigBlueButton server as unavailable to stop scheduling new meetings'
  task :disable, [:id] => :environment do |_t, args|
    include ApiHelper
    Rails.logger.info("Disabling server #{args.id}...")
    server = Server.find(args.id)
    response = true
    if server.load.to_f > 0.0
      puts("WARNING: You are trying to disable a server with active load. You should use the cordon option if
          you do not want to clear all the meetings")
      puts('If you still wish to continue please enter `yes`')
      response = $stdin.gets.chomp.casecmp('yes').zero?
      if response
        meetings = Meeting.all.select { |m| m.server_id == server.id }
        meetings.each do |meeting|
          Rails.logger.info("Clearing Meeting id=#{meeting.id}")
          moderator_pw = meeting.try(:moderator_pw)
          meeting.destroy!
          get_post_req(encode_bbb_uri('end', server.url, server.secret, meetingID: meeting.id, password: moderator_pw))
        rescue ApplicationRedisRecord::RecordNotDestroyed => e
          raise("ERROR: Could not destroy meeting id=#{meeting.id}: #{e}")
        rescue StandardError => e
          warn("WARNING: Could not end meeting id=#{meeting.id}: #{e}")
        end
      end
    end
    server.state = 'disabled' if response
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  end

  desc 'Mark a BigBlueButton server as unavailable, and clear all meetings from it'
  task :panic, [:id, :keep_state, :skip_end_calls] => :environment do |_t, args|
    Rails.logger.info("Panicking server #{args.id}...")
    args.with_defaults(keep_state: false, skip_end_calls: false)
    include ApiHelper

    server = Server.find(args.id)

    meetings = Meeting.all.select { |m| m.server_id == server.id }
    meetings.each do |meeting|
      Rails.logger.info("Clearing Meeting id=#{meeting.id}")
      moderator_pw = meeting.try(:moderator_pw)
      meeting.destroy!
      get_post_req(encode_bbb_uri('end', server.url, server.secret, meetingID: meeting.id, password: moderator_pw)) unless args.skip_end_calls
    rescue ApplicationRedisRecord::RecordNotDestroyed => e
      raise("ERROR: Could not destroy meeting id=#{meeting.id}: #{e}")
    rescue StandardError => e
      warn("WARNING: Could not end meeting id=#{meeting.id}: #{e}")
    end
    server.state = 'disabled' unless args.keep_state
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  rescue StandardError => e
    warn("ERROR: Failed to panic server #{args.id} - #{e}")
    exit(1)
  end

  desc 'Set the load-multiplier of a BigBlueButton server'
  task :loadMultiplier, [:id, :load_multiplier] => :environment do |_t, args|
    server = Server.find(args.id)
    tmp_load_multiplier = 1.0
    unless args.load_multiplier.nil?
      tmp_load_multiplier = args.load_multiplier.to_d
      if tmp_load_multiplier.zero?
        Rails.logger.info('WARNING! Load-multiplier was not readable or 0, so it is now 1')
        tmp_load_multiplier = 1.0
      end
    end
    server.load_multiplier = tmp_load_multiplier
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  end

  desc 'Set the tag of a BigBlueButton server'
  task :tag, [:id, :tag] => :environment do |_t, args|
    server = Server.find(args.id)
    server.tag = args.tag.presence
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    warn("ERROR: No server found with id: #{args.id}")
    exit(1)
  end

  desc 'Adds multiple BigBlueButton servers defined in a YAML file passed as an argument'
  task :addAll, [:path] => :environment do |_t, args|
    servers = YAML.load_file(args.path)['servers']
    servers.each do |server|
      created = Server.create!(url: server['url'], secret: server['secret'])
      puts("server: #{created.url}")
      puts("id: #{created.id}")
    end
  rescue StandardError => e
    warn(e)
    # Should there be an exit(1) here?
  end

  desc 'Sync cluster state with servers defined in a YAML file'
  task :sync, [:path, :mode, :dryrun] => :environment do |_t, args|
    raise "Missing 'path' parameter" if args.path.blank?
    args.with_defaults(mode: 'cordon', dryrun: false)

    ServerSync.sync_file(args.path, args.mode, args.dryrun)
  rescue StandardError => e
    warn("ERROR: #{e}")
    exit(1)
  end

  desc 'Return a yaml compatible with servers:sync'
  task :yaml, [:verbose] => :environment do |_t, args|
    puts({ 'servers' => ServerSync.dump(!!args.verbose) }.to_yaml)
  end

  desc('List all meetings running in specific BigBlueButton servers')
  task :meeting_list, [:server_ids] => :environment do |_t, args|
    include ApiHelper

    args.with_defaults(server_ids: '')
    server_ids = args.server_ids.split(':')
    servers = if server_ids.present?
                server_ids.map { |id| Server.find(id) }
              else
                Server.all
              end
    pool = Concurrent::FixedThreadPool.new(Rails.configuration.x.poller_threads.to_i - 1, name: 'sync-meeting-data')
    tasks = servers.map do |server|
      Concurrent::Promises.future_on(pool) do
        puts("\nServer ID: #{server.id}")
        puts("Server Url: #{server.url}")
        resp = get_post_req(encode_bbb_uri('getMeetings', server.url, server.secret))
        meetings = resp.xpath('/response/meetings/meeting')
        meeting_ids = meetings.map { |meeting| meeting.xpath('.//meetingName').text }
        puts("MeetingIDs: \n\t#{meeting_ids.join("\n\t")}")
        warn("\tNo meetings to display") if meeting_ids.empty?
      rescue BBBErrors::BBBError => e
        warn("\nFailed to get server id=#{server.id} status: #{e}")
      rescue StandardError => e
        warn("\nFailed to get meetings list status: #{e}")
      end
    end
    begin
      Concurrent::Promises.zip_futures_on(pool, *tasks).wait!(Rails.configuration.x.poller_wait_timeout)
    rescue StandardError => e
      Rails.logger.warn("Error #{e}")
    end

    pool.shutdown
    pool.wait_for_termination(5) || pool.kill
  end
end
