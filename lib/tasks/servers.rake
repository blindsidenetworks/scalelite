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
    puts("\t#{server.online ? 'online' : 'offline'}")
  end
end

namespace :servers do
  desc 'Add a new BigBlueButton server (it will be added disabled)'
  task :add, [:url, :secret] => :environment do |_t, args|
    server = Server.create!(url: args.url, secret: args.secret)
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

  desc 'Adds multiple BigBlueButton servers defined in a YAML file passed as an argument'
  task :addAll, [:path] => :environment do |_t, args|
    servers = YAML.load_file(args.path)['servers']
    servers.each do |server|
      created = Server.create!(url: server['url'], secret: server['secret'])
      puts "server: #{created.url}"
      puts "id: #{created.id}"
    end
  end
end
