# frozen_string_literal: true

require 'ostruct'

desc('List all BigBlueButton servers and all meetings currently running')
task status: :environment do
  include ApiHelper

  servers_info = []
  ServerInfo = Struct.new(:hostname, :state, :status, :meetings, :users, :largest, :videos, :load, :bbb_version, :tag)

  Server.all.each do |server|
    state = server.state
    enabled = server.enabled
    state = server.state.present? ? status_with_state(state) : status_without_state(enabled)

    info = ServerInfo.new(URI.parse(server.url).host, state, server.online ? 'online' : 'offline', server.meetings, server.users,
server.largest_meeting, server.videos, server.load, server.bbb_version, server.tag)

    # Convert to openstruct to allow dot syntax usage
    servers_info.push(info)

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
    t.add_column('LOAD', &:load)
    t.add_column('BBB VERSION', &:bbb_version)
    t.add_column('TAG', &:tag)
  end

  puts "\n#{table.pack(max_table_width: nil)}"
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
