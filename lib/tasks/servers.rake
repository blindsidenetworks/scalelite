# frozen_string_literal: true

desc('List configured BigBlueButton servers')
task servers: :environment do
  servers = Server.all
  puts('No servers are configured') if servers.empty?
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
    puts("\t#{server.online ? 'online' : 'offline'}")
  end
end

namespace :servers do
  desc 'Add a new BigBlueButton server (it will be added disabled)'
  task :add, [:url, :secret, :load_multiplier] => :environment do |_t, args|
    if args.url.nil? || args.secret.nil?
      puts('Error: Please input at least a URL and a secret!')
      exit(1)
    end
    tmp_load_multiplier = 1.0
    unless args.load_multiplier.nil?
      tmp_load_multiplier = args.load_multiplier.to_d
      if tmp_load_multiplier.zero?
        puts('WARNING! Load-multiplier was not readable or 0, so it is now 1')
        tmp_load_multiplier = 1.0
      end
    end
    server = Server.create!(url: args.url, secret: args.secret, load_multiplier: tmp_load_multiplier)
    puts('OK')
    puts("id: #{server.id}")
  end

  desc 'Remove a BigBlueButton server'
  task :remove, [:id] => :environment do |_t, args|
    server = Server.find(args.id)
    server.destroy!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end

  desc 'Mark a BigBlueButton server as available for scheduling new meetings'
  task :enable, [:id] => :environment do |_t, args|
    server = Server.find(args.id)
    server.state = 'enabled'
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end

  desc 'Mark a BigBlueButton server as cordoned to stop scheduling new meetings but consider for
        load calculation and joining existing meetings'
  task :cordon, [:id] => :environment do |_t, args|
    server = Server.find(args.id)
    server.state = 'cordoned'
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end

  desc 'Mark a BigBlueButton server as unavailable to stop scheduling new meetings'
  task :disable, [:id] => :environment do |_t, args|
    include ApiHelper
    server = Server.find(args.id)
    response = true
    if server.load.to_f > 0.0
      puts("WARNING: You are trying to disable a server with active load. You should use the cordon option if
          you do not want to clear all the meetings")
      puts('If you still wish to continue please enter `yes`')
      response = STDIN.gets.chomp.casecmp('yes').zero?
      if response
        meetings = Meeting.all.select { |m| m.server_id == server.id }
        meetings.each do |meeting|
          puts("Clearing Meeting id=#{meeting.id}")
          moderator_pw = meeting.try(:moderator_pw)
          meeting.destroy!
          get_post_req(encode_bbb_uri('end', server.url, server.secret, meetingID: meeting.id, password: moderator_pw))
        rescue ApplicationRedisRecord::RecordNotDestroyed => e
          raise("ERROR: Could not destroy meeting id=#{meeting.id}: #{e}")
        rescue StandardError => e
          puts("WARNING: Could not end meeting id=#{meeting.id}: #{e}")
        end
      end
    end
    server.state = 'disabled' if response
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end

  desc 'Mark a BigBlueButton server as unavailable, and clear all meetings from it'
  task :panic, [:id, :keep_state] => :environment do |_t, args|
    args.with_defaults(keep_state: false)
    include ApiHelper

    server = Server.find(args.id)

    meetings = Meeting.all.select { |m| m.server_id == server.id }
    meetings.each do |meeting|
      puts("Clearing Meeting id=#{meeting.id}")
      moderator_pw = meeting.try(:moderator_pw)
      meeting.destroy!
      get_post_req(encode_bbb_uri('end', server.url, server.secret, meetingID: meeting.id, password: moderator_pw))
    rescue ApplicationRedisRecord::RecordNotDestroyed => e
      raise("ERROR: Could not destroy meeting id=#{meeting.id}: #{e}")
    rescue StandardError => e
      puts("WARNING: Could not end meeting id=#{meeting.id}: #{e}")
    end
    server.state = 'disabled' unless args.keep_state
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end

  desc 'Set the load-multiplier of a BigBlueButton server'
  task :loadMultiplier, [:id, :load_multiplier] => :environment do |_t, args|
    server = Server.find(args.id)
    tmp_load_multiplier = 1.0
    unless args.load_multiplier.nil?
      tmp_load_multiplier = args.load_multiplier.to_d
      if tmp_load_multiplier.zero?
        puts('WARNING! Load-multiplier was not readable or 0, so it is now 1')
        tmp_load_multiplier = 1.0
      end
    end
    server.load_multiplier = tmp_load_multiplier
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end

  desc 'Adds multiple BigBlueButton servers defined in a YAML file passed as an argument'
  task :addAll, [:path] => :environment do |_t, args|
    servers = YAML.load_file(args.path)['servers']
    servers.each do |server|
      created = Server.create!(url: server['url'], secret: server['secret'])
      puts "server: #{created.url}"
      puts "id: #{created.id}"
    end
  rescue StandardError => e
    puts(e)
  end

  desc 'Sync cluster state with servers defined in a YAML file'
  task :sync, [:path, :mode] => :environment do |_t, args|
    include ApiHelper

    args.with_defaults(mode: 'cordon')

    config = if args.path == '-'
               YAML.safe_load(STDIN.read)
             elsif args.path.present?
               YAML.safe_load(File.read(args.path))
             else
               raise "Missing 'path' parameter"
             end

    raise 'No \'servers\' hash in config file.' unless config['servers'].is_a?(Hash)

    config['servers'].each do |id, opts|
      raise "Server id=#{id} contains invalid characters" unless /^[a-zA-Z0-9_.-]+$/.match?(id)
      raise "No secret for server id=#{id}" if opts['secret'].blank?

      opts['url'] = "https://#{id}/bigbluebutton/api" if opts['url'].nil?
      begin
        uri = URI.parse(opts['url'])
        raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && !uri.host.nil?
      rescue URI::InvalidURIError
        raise "Invalid url=#{opts['url']} for server id=#{id}"
      end
      opts['enabled'] = opts['enabled'].nil? || !!opts['enabled']
      opts['load_multiplier'] = 1.0 if opts['load_multiplier'].nil? || opts['load_multiplier'].to_d <= 0

      unknown = opts.keys - %w[url secret enabled load_multiplier]
      raise "Bad parameters for server id=#{id} (#{unknown})" unless unknown.empty?
    end

    # Create or update servers according to YAML
    config['servers'].each do |id, opts|
      begin
        server = Server.find(id)
      rescue ApplicationRedisRecord::RecordNotFound
        puts("Creating new server id=#{id}")
        server = Server.create!(
          id: id,
          url: opts['url'],
          secret: opts['secret'],
          load_multiplier: opts['load_multiplier']
        )
      end

      unless server.url == opts['url']
        puts("Updating server id=#{server.id} url=#{opts['url']}")
        server.url = opts['url']
      end
      unless server.secret == opts['secret']
        puts("Updating server id=#{server.id} secret=*****")
        server.secret = opts['secret']
      end
      unless server.load_multiplier.to_d == opts['load_multiplier']
        puts("Updating server id=#{server.id} load_multiplier=#{opts['load_multiplier']}")
        server.load_multiplier = opts['load_multiplier']
      end

      if opts['enabled'] && !server.enabled?
        puts("Enabling server id=#{server.id}")
        server.state = 'enabled'
      elsif !opts['enabled'] && server.enabled?
        puts("Disabling server id=#{server.id}")
        server.state = 'cordoned'
      end

      server.save! if server.changed?
    end

    # Remove servers not present in YAML
    Server.all.each do |server|
      next if config['servers'].key?(server.id)

      meetings = Meeting.all.select { |m| m.server_id == server.id }

      if meetings.empty?
        puts("Removing server id=#{server.id}")
        server.destroy!
        next
      end

      puts("WARNING: Cannot remove server id=#{meeting.id} (not empty)")
      if server.enabled?
        puts("Disabling server id=#{server.id}")
        server.state = 'cordoned'
        server.save!
      end

      next unless args.mode == 'panic'

      # Panic (force) mode -> Forcefully end all meetings
      meetings.each do |meeting|
        puts("Ending meeting id=#{meeting.id} (forced)")
        begin
          get_post_req(
            encode_bbb_uri(
              'end',
              server.url,
              server.secret,
              meetingID: meeting.id,
              password: meeting.try(:moderator_pw)
            )
          )
        rescue StandardError => e
          # Not fatal (may have ended already)
          puts("WARNING: Failed to end meeting id=#{meeting.id}: #{e}")
        end
        meeting.destroy!
      end

      # Check that no new meetings were created while we were busy
      raise "Server id=#{server.id} still not empty!" \
        if Meeting.all.any? { |m| m.server_id == server.id }

      puts("Removing server id=#{server.id} (forced)")
      server.destroy!
    end

  rescue StandardError => e
    puts("ERROR: #{e}")
    exit(1)
  end
end
