# frozen_string_literal: true

require 'concurrent-ruby'

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
    pool = Concurrent::FixedThreadPool.new(ENV.fetch('POLLER_THREADS', 5).to_i - 1, name: 'sync-server-data')
    tasks = Server.all.map do |server|
      Concurrent::Promises.future_on(pool) do
        Rails.logger.debug("Polling Server id=#{server.id}")
        resp = get_post_req(encode_bbb_uri('getMeetings', server.url, server.secret))
        meetings = resp.xpath('/response/meetings/meeting')

        total_attendees = 0
        load_min_user_count = Rails.configuration.x.load_min_user_count
        x_minutes_ago = Rails.configuration.x.load_join_buffer_time.ago

        meetings.each do |meeting|
          created_time = Time.zone.at(meeting.xpath('.//createTime').text.to_i / 1000)
          actual_attendees = meeting.xpath('.//participantCount').text.to_i + meeting.xpath('.//moderatorCount').text.to_i
          total_attendees += if created_time > x_minutes_ago
                               [actual_attendees, load_min_user_count].max
                             else
                               actual_attendees
                             end
        end
        # Reset unhealthy counter so that only consecutive unhealthy calls are counted
        server.reset_unhealthy_counter

        if server.online
          # Update the load if the server is currently online
          server.load = total_attendees * (server.load_multiplier.nil? ? 1.0 : server.load_multiplier.to_d)
        else
          # Only bring the server online if the number of successful requests is >= the acceptable threshold
          next if server.increment_healthy < Rails.configuration.x.server_healthy_threshold

          Rails.logger.info("Server id=#{server.id} is healthy. Bringing back online...")
          server.reset_counters
          server.load = total_attendees * (server.load_multiplier.nil? ? 1.0 : server.load_multiplier.to_d)
          server.online = true
        end
      rescue StandardError => e
        Rails.logger.warn("Failed to get server id=#{server.id} status: #{e}")

        # Reset healthy counter so that only consecutive healthy calls are counted
        server.reset_healthy_counter

        next unless server.online # Only check healthiness if server is currently online

        # Only take the server offline if the number of failed requests is >= the acceptable threshold
        next if server.increment_unhealthy < Rails.configuration.x.server_unhealthy_threshold

        Rails.logger.warn("Server id=#{server.id} is unhealthy. Panicking and setting offline...")
        Rake::Task['servers:panic'].invoke(server.id, true) # Panic server to clear meetings
        server.reset_counters
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
    Concurrent::Promises.zip_futures_on(pool, *tasks).wait!
    pool.shutdown
    pool.wait_for_termination(5) || pool.kill
  end

  desc 'Check all meetings to clear ended meetings'
  task meetings: :environment do
    include ApiHelper

    Rails.logger.debug('Polling meetings')
    pool = Concurrent::FixedThreadPool.new(ENV.fetch('POLLER_THREADS', 5).to_i - 1, name: 'sync-meeting-data')
    tasks = Meeting.all.map do |meeting|
      Concurrent::Promises.future_on(pool) do
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
    Concurrent::Promises.zip_futures_on(pool, *tasks).wait!

    pool.shutdown
    pool.wait_for_termination(5) || pool.kill
  end

  desc 'Run all pollers once'
  multitask all: [:servers, :meetings]
end
