# frozen_string_literal: true

require 'concurrent-ruby'

desc('List all/specific meetings running in BigBlueButton servers')
task :meetings, [:meeting_ids] => :environment do |_t, args|
  include ApiHelper

  args.with_defaults(meeting_ids: '')
  meeting_ids = args.meeting_ids.split(':')

  meetings = if meeting_ids.present?
               meeting_ids.map { |id| Meeting.find(id) }
             else
               Meeting.all
             end
  pool = Concurrent::FixedThreadPool.new(Rails.configuration.x.poller_threads.to_i - 1, name: 'list-meeting-data')
  tasks = meetings.map do |meeting|
    Concurrent::Promises.future_on(pool) do
      meeting_server = meeting.server
      response = get_post_req(encode_bbb_uri('getMeetingInfo', meeting_server.url,
                                             meeting_server.secret, meetingID: meeting.id))
      meeting_id = response.xpath('/response/meetingID').text
      Rails.logger.info("\nMeetingID: #{meeting_id}")
      Rails.logger.info("\tServer ID: #{meeting_server.id}")
      Rails.logger.info("\tServer Url: #{meeting_server.url}")
    rescue BBBErrors::BBBError => e
      Rails.logger.error("\nFailed to get meeting id=#{meeting.id} status: #{e}")
    rescue StandardError => e
      Rails.logger.error("\nFailed to get meetings list status: #{e}")
    end
  end
  begin
    Concurrent::Promises.zip_futures_on(pool, *tasks).wait!(Rails.configuration.x.poller_wait_timeout)
  rescue StandardError => e
    Rails.logger.warn("Error #{e}")
  end
end

namespace :meetings do
  desc('List all/specific meetings running in BigBlueButton servers')
  task :list, [:meeting_ids] => :meetings

  desc('End all/specific meetings running in BigBlueButton servers')
  task :end, [:meeting_ids] => :environment do |_t, args|
    $stdout.sync = true
    Rails.logger.info('WARNING: You are trying to clear active meetings.')
    Rails.logger.info('If you still wish to continue please enter `yes`')
    response = $stdin.gets.chomp.casecmp('yes').zero?
    if response
      args.with_defaults(meeting_ids: '')
      include ApiHelper

      meeting_ids = args.meeting_ids.split(':')
      meetings = if meeting_ids.present?
                   meeting_ids.map { |id| Meeting.find(id) }
                 else
                   Meeting.all
                 end
      Rails.logger.info('No meetings to clear') if meetings.empty?
      pool = Concurrent::FixedThreadPool.new(Rails.configuration.x.poller_threads.to_i - 1, name: 'end-meeting')
      tasks = meetings.map do |meeting|
        Concurrent::Promises.future_on(pool) do
          meeting_server = meeting.server
          moderator_pw = meeting.try(:moderator_pw)
          meeting.destroy!
          get_post_req(encode_bbb_uri('end', meeting_server.url, meeting_server.secret,
                                      meetingID: meeting.id, password: moderator_pw))
          Rails.logger.info("Clearing Meeting id=#{meeting.id}")
        rescue ApplicationRedisRecord::RecordNotDestroyed => e
          raise("ERROR: Could not destroy meeting id=#{meeting.id}: #{e}")
        rescue StandardError => e
          Rails.logger.error("WARNING: Could not end meeting id=#{meeting.id}: #{e}")
        end
      end
      begin
        Concurrent::Promises.zip_futures_on(pool, *tasks).wait!(Rails.configuration.x.poller_wait_timeout)
      rescue StandardError => e
        Rails.logger.warn("Error #{e}")
      end
      pool.shutdown
      pool.wait_for_termination(5) || pool.kill
    end
    Rails.logger.info('OK')
  end

  desc('Get meeting details running in BigBlueButton servers')
  task :info, [:meeting_id] => :environment do |_t, args|
    if args.meeting_id.nil?
      Rails.logger.error('Error: Please input a meetingID!')
      exit(1)
    end
    include ApiHelper

    meeting_id = args.meeting_id
    meeting = Meeting.find(meeting_id)
    Rails.logger.info('No meeting info to show') if meeting.nil?
    meeting_server = meeting.server
    response = get_post_req(encode_bbb_uri('getMeetingInfo', meeting_server.url,
                                           meeting_server.secret, meetingID: meeting.id))
    Rails.logger.info("\nMeeting ID: #{response.xpath('/response/meetingID').text}")
    Rails.logger.info("\tMeeting Name: #{response.xpath('/response/meetingName').text}")
    Rails.logger.info("\tInternal MeetingID: #{response.xpath('/response/internalMeetingID').text}")
    Rails.logger.info("\tCreated Date: #{response.xpath('/response/createDate').text}")
    Rails.logger.info("\tRecording Enabled: #{response.xpath('/response/recording').text}")
    Rails.logger.info("\tServer id: #{meeting_server.id}")
    Rails.logger.info("\tSerevr url: #{meeting_server.url}")
    metadata = response.xpath('/response/metadata')
    Rails.logger.info("\tMetaData:")
    Rails.logger.info("\t\tbbb-context-name: #{metadata.xpath('.//bbb-context-name').text}")
    Rails.logger.info("\t\tanalytics-callback-url: #{metadata.xpath('.//analytics-callback-url').text}")
    Rails.logger.info("\t\tbbb-recording-tags: #{metadata.xpath('.//bbb-recording-tags').text}")
    Rails.logger.info("\t\tbbb-origin-server-common-name: #{metadata.xpath('.//bbb-origin-server-common-name').text}")
    Rails.logger.info("\t\tbbb-context-label: #{metadata.xpath('.//bbb-context-label').text}")
    Rails.logger.info("\t\tbbb-origin: #{metadata.xpath('.//bbb-context-name').text}")
    Rails.logger.info("\t\tbbb-context: #{metadata.xpath('.//bbb-context').text}")
    Rails.logger.info("\t\tbbb-context-id: #{metadata.xpath('.//bbb-context-id').text}")
    Rails.logger.info("\t\tbbb-recording-name: #{metadata.xpath('.//bbb-recording-name').text}")
    Rails.logger.info("\t\tbbb-origin-server-name: #{metadata.xpath('.//bbb-origin-server-name').text}")
    Rails.logger.info("\t\tbbb-recording-description: #{metadata.xpath('.//bbb-recording-description').text}")
    Rails.logger.info("\t\tbbb-origin-tag: #{metadata.xpath('.//bbb-origin-tag').text}")
  rescue StandardError => e
    Rails.logger.error("WARNING: Could not get info for meeting id=#{meeting.id}: #{e}")
  end
end
