# frozen_string_literal: true

desc('List configured BigBlueButton servers')
task servers: :environment do
  servers = Server.all
  puts('No servers are configured') if servers.empty?
  servers.each do |server|
    puts("id: #{server.id}")
    puts("\turl: #{server.url}")
    puts("\tsecret: #{server.secret}")
    puts("\t#{server.enabled ? 'enabled' : 'disabled'}")
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
    server.enabled = true
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end

  desc 'Mark a BigBlueButton server as unavailable to stop scheduling new meetings'
  task :disable, [:id] => :environment do |_t, args|
    server = Server.find(args.id)
    server.enabled = false
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
    server.enabled = false unless args.keep_state
    server.save!

    meetings = Meeting.all.select { |m| m.server_id == server.id }
    meetings.each do |meeting|
      puts("Clearing Meeting id=#{meeting.id}")
      meeting.destroy!
      moderator_pw = meeting.try(:moderator_pw)
      get_post_req(encode_bbb_uri('end', server.url, server.secret, meetingID: meeting.id, password: moderator_pw))

    rescue ApplicationRedisRecord::RecordNotDestroyed => e
      puts("WARNING: Could not destroy meeting id=#{meeting.id}: #{e}")
    rescue StandardError => e
      puts("WARNING: Could not end meeting id=#{meeting.id}: #{e}")
    end
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
end
