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
      puts("\nMeetingID: #{meeting_id}")
      puts("\tServer ID: #{meeting_server.id}")
      puts("\tServer Url: #{meeting_server.url}")
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
    puts('WARNING: You are trying to clear active meetings.')
    puts('If you still wish to continue please enter `yes`')
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
      warn('No meetings to clear') if meetings.empty?
      pool = Concurrent::FixedThreadPool.new(Rails.configuration.x.poller_threads.to_i - 1, name: 'end-meeting')
      tasks = meetings.map do |meeting|
        Concurrent::Promises.future_on(pool) do
          meeting_server = meeting.server
          moderator_pw = meeting.try(:moderator_pw)
          meeting.destroy!
          get_post_req(encode_bbb_uri('end', meeting_server.url, meeting_server.secret,
                                      meetingID: meeting.id, password: moderator_pw))
          warn("Clearing Meeting id=#{meeting.id}")
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
    puts('OK')
  end

  desc('Get meeting details running in BigBlueButton servers')
  task :info, [:meeting_id] => :environment do |_t, args|
    if args.meeting_id.nil?
      warn('Error: Please input a meetingID!')
      exit(1)
    end
    include ApiHelper

    meeting_id = args.meeting_id
    meeting = Meeting.find(meeting_id)
    warn('No meeting info to show') if meeting.nil?
    meeting_server = meeting.server
    response = get_post_req(encode_bbb_uri('getMeetingInfo', meeting_server.url,
                                           meeting_server.secret, meetingID: meeting.id))
    puts("\nMeeting ID: #{response.xpath('/response/meetingID').text}")
    puts("\tMeeting Name: #{response.xpath('/response/meetingName').text}")
    puts("\tInternal MeetingID: #{response.xpath('/response/internalMeetingID').text}")
    puts("\tCreated Date: #{response.xpath('/response/createDate').text}")
    puts("\tRecording Enabled: #{response.xpath('/response/recording').text}")
    puts("\tServer id: #{meeting_server.id}")
    puts("\tSerevr url: #{meeting_server.url}")
    metadata = response.xpath('/response/metadata')
    puts("\tMetaData:")
    puts("\t\tbbb-context-name: #{metadata.xpath('.//bbb-context-name').text}")
    puts("\t\tanalytics-callback-url: #{metadata.xpath('.//analytics-callback-url').text}")
    puts("\t\tbbb-recording-tags: #{metadata.xpath('.//bbb-recording-tags').text}")
    puts("\t\tbbb-origin-server-common-name: #{metadata.xpath('.//bbb-origin-server-common-name').text}")
    puts("\t\tbbb-context-label: #{metadata.xpath('.//bbb-context-label').text}")
    puts("\t\tbbb-origin: #{metadata.xpath('.//bbb-context-name').text}")
    puts("\t\tbbb-context: #{metadata.xpath('.//bbb-context').text}")
    puts("\t\tbbb-context-id: #{metadata.xpath('.//bbb-context-id').text}")
    puts("\t\tbbb-recording-name: #{metadata.xpath('.//bbb-recording-name').text}")
    puts("\t\tbbb-origin-server-name: #{metadata.xpath('.//bbb-origin-server-name').text}")
    puts("\t\tbbb-recording-description: #{metadata.xpath('.//bbb-recording-description').text}")
    puts("\t\tbbb-origin-tag: #{metadata.xpath('.//bbb-origin-tag').text}")
  rescue StandardError => e
    warn("WARNING: Could not get info for meeting id=#{meeting.id}: #{e}")
  end
end
