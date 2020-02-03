# frozen_string_literal: true

require 'test_helper'

class ServerTest < ActiveSupport::TestCase
  include ActiveModel::Lint::Tests

  setup do
    @model = Server.new
  end

  test 'Server find with non-existent id' do
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Server.find('non-existent-id')
    end
  end

  test 'Server find with no load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
    end

    server = Server.find('test-1')

    assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
    assert_equal('test-1', server.secret)
    assert_nil(server.load)
  end

  test 'Server find with load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
      redis.zadd('server_load', 1, 'test-1')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find('test-2')

    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2', server.secret)
    assert_equal(2, server.load)
  end

  test 'Server find_available with no available servers' do
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Server.find_available
    end
  end

  test 'Server find_available with missing server hash' do
    RedisStore.with_connection do |redis|
      redis.zadd('server_load', 0, 'test-id')
    end
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Server.find_available
    end
  end

  test 'Server find_available returns server with lowest load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
      redis.zadd('server_load', 1, 'test-1')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find_available
    assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
    assert_equal('test-1', server.secret)
    assert_equal(1, server.load)
  end
end
