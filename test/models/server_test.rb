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
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
    end

    server = Server.find('test-1')

    assert_equal('test-1', server.id)
    assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
    assert_equal('test-1-secret', server.secret)
    assert_nil(server.load)
  end

  test 'Server find with load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.zadd('server_load', 1, 'test-1')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find('test-2')

    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
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
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.zadd('server_load', 1, 'test-1')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find_available
    assert_equal('test-1', server.id)
    assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
    assert_equal('test-1-secret', server.secret)
    assert_equal(1, server.load)
  end

  test 'Server all with no servers' do
    servers = Server.all
    assert_empty(servers)
  end

  test 'Server all returns all servers' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd('servers', 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.sadd('servers', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret')
    end

    servers = Server.all
    assert_equal(2, servers.length)
    assert_not_equal(servers[0].id, servers[1].id)
    servers.each do |server|
      case server.id
      when 'test-1'
        assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
        assert_equal('test-1-secret', server.secret)
        assert_nil(server.load)
      when 'test-2'
        assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
        assert_equal('test-2-secret', server.secret)
        assert_equal(2, server.load)
      else
        flunk("Returned unexpected server #{server.id}")
      end
    end
  end

  test 'Server availabe returns available servers' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd('servers', 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.sadd('servers', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret')
    end

    servers = Server.available
    assert_equal(1, servers.length)
    server = servers[0]
    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
    assert_equal(2, server.load)
  end
end
