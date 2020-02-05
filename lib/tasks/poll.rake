# frozen_string_literal: true

namespace :poll do
  desc 'Check all servers to update their online and load status'
  task servers: :environment do
    include ApiHelper
    Server.all.each do |server|
      resp = get_req(encode_bbb_uri('getMeetings', server.url, server.secret))
      meetings = resp.xpath('/response/meetings/meeting')
      server.load = meetings.length
      server.online = true
    rescue StandardError => e
      Rails.logger.warn("Failed to get server id=#{server.id} status: #{e}")
      server.load = nil
      server.online = false
    ensure
      Rails.logger.info("Server id=#{server.id} load: #{server.load}")
      server.save!
    end
  end
end
