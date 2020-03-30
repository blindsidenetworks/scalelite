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
    puts("\tload multiplier: #{server.loadMultiplier}")
    puts("\t#{server.online ? 'online' : 'offline'}")
  end
end

namespace :servers do
  desc 'Add a new BigBlueButton server (it will be added disabled)'
  task :add, [:url, :secret, :loadMultiplier] => :environment do |_t, args|
    if !args.url.present? || !args.secret.present?
      puts 'Error: Please input at least a URL and a secret!'
      exit 1
    end
    __loadMultiplier = 1.0
    if args.loadMultiplier.present?
      __loadMultiplier = args.loadMultiplier.to_d
      if __loadMultiplier == 0
        puts 'WARNING! Load-multiplier was not readable or 0, so it is now 1'
        __loadMultiplier = 1.0
      end
    end
    server = Server.create!(url: args.url, secret: args.secret, loadMultiplier: __loadMultiplier)
    puts 'OK'
    puts "id: #{server.id}"
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
  task :panic, [:id] => :environment do |_t, args|
    include ApiHelper

    server = Server.find(args.id)
    server.enabled = false
    server.save!

    meetings = Meeting.all.select { |m| m.server_id == server.id }
    meetings.each do |meeting|
      puts("Clearing Meeting id=#{meeting.id}")
      meeting.destroy!

      get_post_req(encode_bbb_uri('end', server.url, server.secret, meetingID: meeting.id))
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
  task :loadMultiplier, [:id,:loadMultiplier] => :environment do |_t, args|
    server = Server.find(args.id)
    __loadMultiplier = 1.0
    if args.loadMultiplier.present?
      __loadMultiplier = args.loadMultiplier.to_d
      if __loadMultiplier == 0
        puts 'WARNING! Load-multiplier was not readable or 0, so it is now 1'
        __loadMultiplier = 1.0
      end
    end
    server.loadMultiplier = __loadMultiplier
    server.save!
    puts('OK')
  rescue ApplicationRedisRecord::RecordNotFound
    puts("ERROR: No server found with id: #{args.id}")
  end
end
