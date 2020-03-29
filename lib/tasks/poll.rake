# frozen_string_literal: true

desc 'Run a polling process to continually monitor servers and meetings'
task :poll, [:interval] => :environment do |_t, args|
  args.with_defaults(interval: 60.seconds)
  interval = args.interval.to_f
  Rails.logger.info("Running poller with interval #{interval}")

  poll_all_task = Rake::Task['poll:all']
  loop do
    begin
      poll_all_task.invoke
    rescue Redis::CannotConnectError => e
      Rails.logger.warn(e)
    end

    sleep(interval)

    poll_all_task.reenable
    poll_all_task.prerequisite_tasks.each(&:reenable)
  end
rescue SignalException => e
  Rails.logger.info("Exiting poller on signal: #{e}")
end

namespace :poll do
  desc 'Check all servers to update their online and load status'
  task servers: :environment do
    include ApiHelper

    Rails.logger.debug('Polling servers')
    Server.all.each do |server|
      Rails.logger.debug("Polling Server id=#{server.id}")
      resp = get_post_req(encode_bbb_uri('getMeetings', server.url, server.secret))
      meetings = resp.xpath('/response/meetings/meeting')

      server_users = 0
      video_streams = 0

      meetings.each do |meeting|
        count = meeting.at_xpath('participantCount')
        users = count.present? ? count.text.to_i : 0
        server_users += users

        streams = meeting.at_xpath('videoCount')
        video_streams += streams.present? ? streams.text.to_i : 0
      end

      server.load = video_streams * 100 + server_users * 10 + meetings.length
      server.online = true
    rescue StandardError => e
      Rails.logger.warn("Failed to get server id=#{server.id} status: #{e}")
      server.load = nil
      server.online = false
    ensure
      begin
        server.save!
        Rails.logger.info(
          "Server id=#{server.id} #{server.online ? 'online' : 'offline'} " \
          "load: #{server.load.nil? ? 'unavailable' : server.load}"
        )
      rescue ApplicationRedisRecord::RecordNotSaved => e
        Rails.logger.warn("Unable to update Server id=#{server.id}: #{e}")
      end
    end
  end

  desc 'Check all meetings to clear ended meetings'
  task meetings: :environment do
    include ApiHelper

    Rails.logger.debug('Polling meetings')
    Meeting.all.each do |meeting|
      server = meeting.server
      Rails.logger.debug("Polling Meeting id=#{meeting.id} on Server id=#{server.id}")
      get_post_req(encode_bbb_uri('getMeetingInfo', server.url, server.secret, meetingID: meeting.id))
    rescue BBBErrors::BBBError => e
      unless e.message_key == 'notFound'
        Rails.logger.warn("Unexpected BigBlueButton error polling Meeting id=#{meeting.id} on Server id=#{server.id}: #{e}")
        next
      end

      begin
        meeting.destroy!
        Rails.logger.info("Meeting id=#{meeting.id} on Server id=#{server.id} has ended")
      rescue ApplicationRedisRecord::RecordNotSaved => e
        Rails.logger.warn("Unable to destroy meeting id=#{meeting.id}: #{e}")
      end
    rescue StandardError => e
      Rails.logger.warn("Failed to check meeting id=#{meeting.id} status: #{e}")
    end
  end

  desc 'Run all pollers once'
  multitask all: [:servers, :meetings]
end
