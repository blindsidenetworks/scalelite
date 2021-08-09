# frozen_string_literal: true

require 'ostruct'

desc('List all BigBlueButton servers and all meetings currently running')
task status: :environment do
  include ApiHelper

  servers_info = []
  Server.all.each do |server|
    state = server.state
    enabled = server.enabled
    state = server.state.present? ? status_with_state(state) : status_without_state(enabled)

    # Convert to openstruct to allow dot syntax usage
    servers_info.push(OpenStruct.new(
                        hostname: URI.parse(server.url).host,
                        state: state,
                        status: server.online ? 'online' : 'offline',
                        meetings: server.meetings,
                        users: server.users,
                        largest: server.largest_meeting,
                        videos: server.videos
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
