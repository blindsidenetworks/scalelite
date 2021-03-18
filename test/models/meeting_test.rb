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

  test 'Meeting create' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
    end

    server = Server.find('test-server-1')

    meeting = Meeting.new
    meeting.id = 'Demo Meeting'
    meeting.server = server
    meeting.save!

    RedisStore.with_connection do |redis|
      assert(redis.sismember('meetings', 'Demo Meeting'))
      meeting_hash = redis.hgetall('meeting:Demo Meeting')
      assert_equal('test-server-1', meeting_hash['server_id'])
    end
  end

  test 'Meeting atomic create (new meeting)' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
    end

    server = Server.find('test-server-1')
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    assert_equal('Demo Meeting', meeting.id)
    assert_same(server, meeting.server)
    assert_equal('test-server-1', meeting.server_id)

    RedisStore.with_connection do |redis|
      assert(redis.sismember('meetings', 'Demo Meeting'))
      meeting_hash = redis.hgetall('meeting:Demo Meeting')
      assert_equal('test-server-1', meeting_hash['server_id'])
    end
  end

  test 'Meeting atomic create (existing meeting)' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
      redis.mapped_hmset('server:test-server-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
      redis.sadd('servers', 'test-server-2')
      redis.mapped_hmset('meeting:Demo Meeting', server_id: 'test-server-1')
      redis.sadd('meetings', 'Demo Meeting')
    end

    meeting = Meeting.find('Demo Meeting')
    assert_equal('test-server-1', meeting.server_id)

    server = Server.find('test-server-2')
    meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')
    assert_equal('Demo Meeting', meeting.id)
    assert_not_same(server, meeting.server)
    assert_equal('test-server-1', meeting.server_id)

    RedisStore.with_connection do |redis|
      assert(redis.sismember('meetings', 'Demo Meeting'))
      meeting_hash = redis.hgetall('meeting:Demo Meeting')
      assert_equal('test-server-1', meeting_hash['server_id'])
    end
  end

  test 'Meeting update id' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.sadd('meetings', 'test-meeting-1')
    end

    meeting = Meeting.find('test-meeting-1')
    meeting.id = 'test-meeting-2'
    assert_raises(ApplicationRedisRecord::RecordNotSaved) do
      meeting.save!
    end
  end

  test 'Meeting update server_id' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
      redis.mapped_hmset('server:test-server-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
      redis.sadd('servers', 'test-server-2')
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.sadd('meetings', 'test-meeting-1')
    end

    meeting = Meeting.find('test-meeting-1')
    assert_equal('test-server-1', meeting.server_id)
    meeting.server_id = 'test-server-2'
    meeting.save!

    RedisStore.with_connection do |redis|
      meeting_hash = redis.hgetall('meeting:test-meeting-1')
      assert_equal('test-server-2', meeting_hash['server_id'])
    end
  end

  test 'Meeting update server' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
      redis.mapped_hmset('server:test-server-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
      redis.sadd('servers', 'test-server-2')
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.sadd('meetings', 'test-meeting-1')
    end

    meeting = Meeting.find('test-meeting-1')
    assert_equal('test-server-1', meeting.server.id)
    meeting.server = Server.find('test-server-2')
    meeting.save!

    RedisStore.with_connection do |redis|
      meeting_hash = redis.hgetall('meeting:test-meeting-1')
      assert_equal('test-server-2', meeting_hash['server_id'])
    end
  end

  test 'Meeting destroy' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.sadd('meetings', 'test-meeting-1')
    end

    meeting = Meeting.find('test-meeting-1')
    meeting.destroy!

    RedisStore.with_connection do |redis|
      assert_not(redis.sismember('meetings', 'test-meeting-1'))
      assert_empty(redis.hgetall('meeting:test-meeting-1'))
    end
  end

  test 'Meeting destroy with pending changes' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
      redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
      redis.sadd('meetings', 'test-meeting-1')
    end

    meeting = Meeting.find('test-meeting-1')
    meeting.server_id = 'test-server-2'

    assert_raises(ApplicationRedisRecord::RecordNotDestroyed) do
      meeting.destroy!
    end
  end

  test 'Meeting destroy with non-persisted object' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.sadd('servers', 'test-server-1')
    end

    meeting = Meeting.new
    meeting.server = Server.find('test-server-1')

    assert_raises(ApplicationRedisRecord::RecordNotDestroyed) do
      meeting.destroy!
    end
  end
end
