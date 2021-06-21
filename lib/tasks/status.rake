# frozen_string_literal: true

require 'ostruct'

desc('List all BigBlueButton servers and all meetings currently running')
task status: :environment do
  include ApiHelper

  servers_info = []
  Server.all.each do |server|
    begin
      # Empty defaults
      meetings = []
      server_users = 0
      video_streams = 0
      users_in_largest_meeting = 0

      # Scan only servers that are online
      if server.online
        response = get_post_req(encode_bbb_uri('getMeetings', server.url, server.secret))
        meetings = response.xpath('/response/meetings/meeting')

        meetings.each do |meeting|
          count = meeting.at_xpath('participantCount')
          users = count.present? ? count.text.to_i : 0
          server_users += users
          users_in_largest_meeting = users if users > users_in_largest_meeting

          streams = meeting.at_xpath('videoCount')
          video_streams += streams.present? ? streams.text.to_i : 0
        end
      end
    rescue StandardError
      # Set all values to 0 if request to server fails (server is offline)
      meetings = []
      server_users = 0
      video_streams = 0
      users_in_largest_meeting = 0
    end

    state = server.state
    enabled = server.enabled
    state = server.state.present? ? status_with_state(state) : status_without_state(enabled)

    # Convert to openstruct to allow dot syntax usage
    servers_info.push(OpenStruct.new(
                        hostname: URI.parse(server.url).host,
                        state: state,
                        status: server.online ? 'online' : 'offline',
                        meetings: meetings.length,
                        users: server_users,
                        largest: users_in_largest_meeting,
                        videos: video_streams
                      ))
    # Sort list of servers
    servers_info = servers_info.sort_by(&:hostname)
  end

  table = Tabulo::Table.new(servers_info, border: :blank) do |t|
    t.add_column('HOSTNAME', &:hostname)
    t.add_column('STATE', &:state)
    t.add_column('STATUS', &:status)
    t.add_column('MEETINGS', &:meetings)
    t.add_column('USERS', &:users)
    t.add_column('LARGEST MEETING', &:largest)
    t.add_column('VIDEOS', &:videos)
  end

  puts table.pack
end

def status_with_state(state)
  case state
  when 'cordoned'
    'cordoned'
  when 'enabled'
    'enabled'
  else
    'disabled'
  end
end

def status_without_state(enabled)
  enabled ? 'enabled' : 'disabled'
end
