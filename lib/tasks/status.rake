# frozen_string_literal: true

desc('List all BigBlueButton servers and all meetings currently running')
task status: :environment do
  include ApiHelper

  servers = Server.all
  puts('No servers are configured') if servers.empty?

  servers.each do |server|
    puts("id: #{server.id}")
    puts("\turl: #{server.url}")
    puts("\tsecret: #{server.secret}")
    puts("\t#{server.enabled ? 'enabled' : 'disabled'}")
    puts("\tload: #{server.load.presence || 'unavailable'}")
    puts("\t#{server.online ? 'online' : 'offline'}")

    response = get_post_req(encode_bbb_uri('getMeetings', server.url, server.secret))
    meetings = response.xpath('/response/meetings/meeting')

    server_users = 0
    meetings.each do |meeting|
      count = meeting.at_xpath('participantCount')
      server_users += count.present? ? count.text.to_i : 0
    end

    puts("\ttotal users: #{server_users}")

    puts("\tmeetings:") if meetings.present?
    meetings.each do |meeting|
      puts("\t\tid: #{meeting.at_xpath('meetingID').text}")
      puts("\t\t\tname: #{meeting.at_xpath('meetingName').text}")
      puts("\t\t\tusers: #{meeting.at_xpath('participantCount')&.text}")
    end
  end
end
