# frozen_string_literal: true

desc('List configured BigBlueButton servers')
task servers: :environment do
  servers = Server.all
  puts('No servers are configured') if servers.empty?
  Server.all.each do |server|
    puts("id: #{server.id}")
    puts("\turl: #{server.url}")
    puts("\tsecret: #{server.secret}")
    puts("\t#{server.enabled ? 'enabled' : 'disabled'}")
    puts("\tload: #{server.load}") if server.load.present?
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
end
