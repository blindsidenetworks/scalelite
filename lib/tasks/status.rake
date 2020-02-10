# frozen_string_literal: true

require 'ostruct'

desc('List all BigBlueButton servers and all meetings currently running')
task status: :environment do
  include ApiHelper

  servers_info = []
  Server.all.each do |server|
    response = get_req(encode_bbb_uri('getMeetings', server.url, server.secret))
    meetings = response.xpath('/response/meetings/meeting')

    server_users = 0
    video_streams = 0
    meetings.each do |meeting|
      count = meeting.at_xpath('participantCount')
      server_users += count.present? ? count.text.to_i : 0
      streams = meeting.at_xpath('videoCount')
      video_streams += streams.present? ? streams.text.to_i : 0
    end

    # Convert to openstruct to allow dot syntax usage
    servers_info.push(OpenStruct.new(
                        hostname: URI.parse(server.url).host,
                        state: server.enabled ? 'enabled' : 'disabled',
                        status: server.online ? 'online' : 'offline',
                        meetings: meetings.length,
                        users: server_users,
                        videos: video_streams
                      ))
  end

  table = Tabulo::Table.new(servers_info, border: :blank) do |t|
    t.add_column('HOSTNAME', &:hostname)
    t.add_column('STATE', &:state)
    t.add_column('STATUS', &:status)
    t.add_column('MEETINGS', &:meetings)
    t.add_column('USERS', &:users)
    t.add_column('VIDEOS', &:videos)
  end

  puts table.pack
end
