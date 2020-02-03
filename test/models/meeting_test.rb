# frozen_string_literal: true

require 'test_helper'

class MeetingTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Meeting.new
  end

  test 'Meeting find with non-existent ID' do
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Meeting.find('non-existent-id')
    end
  end

  test 'Meeting find (no server)' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
    end

    meeting = Meeting.find('test-meeting-1')
    assert_equal('test-server-1', meeting.server_id)
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      meeting.server
    end
  end

  test 'Meeting find (with server)' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
    end

    meeting = Meeting.find('test-meeting-1')
    assert_equal('test-server-1', meeting.server_id)
    server = meeting.server
    assert_equal('test-server-1', server.id)
  end

  test 'Meeting all with no meetings' do
    all_meetings = Meeting.all
    assert_empty(all_meetings)
  end

  test 'Meeting all with multiple meetings' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.mapped_hmset('meeting:test-meeting-2', server_id: 'test-server-2')
      redis.sadd('meetings', %w[test-meeting-1 test-meeting-2])
    end

    all_meetings = Meeting.all
    assert_equal(2, all_meetings.length)
    assert_not_equal(all_meetings[0].id, all_meetings[1].id)
  end
end
