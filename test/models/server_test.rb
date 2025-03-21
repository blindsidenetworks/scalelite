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
      redis.sadd?('servers', 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.sadd?('servers', 'test-2')
    end

    server = Server.find('test-1')

    assert_equal('test-1', server.id)
    assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
    assert_equal('test-1-secret', server.secret)
    assert_not(server.enabled)
    assert_nil(server.load)
    assert_not(server.online)
  end

  test 'Server find with load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          online: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find('test-2')

    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
    assert(server.enabled)
    assert_nil(server.state)
    assert_equal(2, server.load)
    assert(server.online)
  end

  test 'Server find with load and state as enabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          online: 'true', state: 'enabled')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find('test-2')

    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
    assert(server.state.eql?('enabled'))
    assert_nil(server.enabled)
    assert_equal(2, server.load)
    assert(server.online)
  end

  test 'Server find disabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.sadd?('servers', 'test-2')
    end

    server = Server.find('test-2')

    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
    assert_nil(server.state)
    assert_not(server.enabled)
    assert_nil(server.load)
  end

  test 'Server find disabled with state as disabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          state: 'disabled')
      redis.sadd?('servers', 'test-2')
    end

    server = Server.find('test-2')

    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
    assert(server.state.eql?('disabled'))
    assert_nil(server.enabled)
    assert_nil(server.load)
  end

  test 'Server find_available with no available servers' do
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Server.find_available
    end
  end

  test 'Server find_available with any tag and no available servers' do
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Server.find_available('test-tag')
    end
  end

  test 'Server find_available with missing server hash' do
    # This is mostly a failsafe check
    RedisStore.with_connection do |redis|
      redis.zadd('server_load', 0, 'test-id')
    end
    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      # Protection against infinite loops
      Timeout.timeout(1) do
        Server.find_available
      end
    end
  end

  test 'Server find_available returns server with lowest load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          enabled: 'false')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find_available
    assert_equal('test-1', server.id)
    assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
    assert_equal('test-1-secret', server.secret)
    assert(server.enabled)
    assert_nil(server.state)
    assert_equal(1, server.load)
  end

  test 'Server find_available returns server with lowest load and state as enabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          state: 'cordoned')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find_available
    assert_equal('test-1', server.id)
    assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
    assert_equal('test-1-secret', server.secret)
    assert(server.state.eql?('enabled'))
    assert_nil(server.enabled)
    assert_equal(1, server.load)
  end

  test 'Server find_available raises no server error if all servers are cordoned' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 1, 'test-2')
    end

    Server.all.each do |server|
      server.state = 'cordoned'
      server.save!
    end

    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Server.find_available
    end
  end

  test 'Server find_available raises no server error if all servers are disabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'false')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          enabled: 'false')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 1, 'test-1')
    end

    Server.all.each do |server|
      server.enabled = false
      server.save!
    end

    assert_raises(ApplicationRedisRecord::RecordNotFound) do
      Server.find_available
    end
  end

  test 'Server find_available without or with empty tag or with none tag returns untagged server with lowest load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          tag: 'test-tag', enabled: 'true')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 3, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-3')
      redis.sadd?('server_enabled', 'test-3')
      redis.zadd('server_load', 2, 'test-3')
    end

    server = Server.find_available
    assert_equal('test-3', server.id)
    assert_equal('https://test-3.example.com/bigbluebutton/api', server.url)
    assert_equal('test-3-secret', server.secret)
    assert_nil(server.tag)
    assert(server.enabled)
    assert_nil(server.state)
    assert_equal(2, server.load)

    server = Server.find_available('')
    assert_equal('test-3', server.id)

    server = Server.find_available('!')
    assert_equal('test-3', server.id)

    server = Server.find_available('none')
    assert_equal('test-3', server.id)

    server = Server.find_available('none!')
    assert_equal('test-3', server.id)
  end

  test 'Server find_available with tag argument returns matching tagged server with lowest load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          tag: 'test-tag', enabled: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 3, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret',
                                          tag: 'test-tag', enabled: 'true')
      redis.sadd?('servers', 'test-3')
      redis.sadd?('server_enabled', 'test-3')
      redis.zadd('server_load', 2, 'test-3')
      redis.mapped_hmset('server:test-4', url: 'https://test-4.example.com/bigbluebutton/api', secret: 'test-4-secret',
                                          tag: 'wrong-tag', enabled: 'true')
      redis.sadd?('servers', 'test-4')
      redis.sadd?('server_enabled', 'test-4')
      redis.zadd('server_load', 1, 'test-4')
    end

    server = Server.find_available('test-tag')
    assert_equal('test-3', server.id)
    assert_equal('https://test-3.example.com/bigbluebutton/api', server.url)
    assert_equal('test-3-secret', server.secret)
    assert_equal('test-tag', server.tag)
    assert(server.enabled)
    assert_nil(server.state)
    assert_equal(2, server.load)

    server = Server.find_available('test-tag!')
    assert_equal('test-3', server.id)
    assert_equal('test-tag', server.tag)
  end

  test 'Server find_available with multiple tag arguments returns matching tagged server with lowest load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          tag: 'test-tag', enabled: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 3, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret',
                                          tag: 'test-tag2', enabled: 'true')
      redis.sadd?('servers', 'test-3')
      redis.sadd?('server_enabled', 'test-3')
      redis.zadd('server_load', 2, 'test-3')
      redis.mapped_hmset('server:test-4', url: 'https://test-4.example.com/bigbluebutton/api', secret: 'test-4-secret',
                                          tag: 'wrong-tag', enabled: 'true')
      redis.sadd?('servers', 'test-4')
      redis.sadd?('server_enabled', 'test-4')
      redis.zadd('server_load', 1, 'test-4')
    end

    server = Server.find_available('test-tag;test-tag2')
    assert_equal('test-3', server.id)
    assert_equal('https://test-3.example.com/bigbluebutton/api', server.url)
    assert_equal('test-3-secret', server.secret)
    assert_equal('test-tag2', server.tag)
    assert(server.enabled)
    assert_nil(server.state)
    assert_equal(2, server.load)

    server = Server.find_available('test-tag;test-tag2!')
    assert_equal('test-3', server.id)
    assert_equal('test-tag2', server.tag)
  end

  test 'Server find_available with optional tag returns untagged server with lowest load if no matching tagged server available' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 3, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          tag: 'wrong-tag', enabled: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 1, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-3')
      redis.sadd?('server_enabled', 'test-3')
      redis.zadd('server_load', 2, 'test-3')
    end

    server = Server.find_available('test-tag')
    assert_equal('test-3', server.id)
    assert_equal('https://test-3.example.com/bigbluebutton/api', server.url)
    assert_equal('test-3-secret', server.secret)
    assert_nil(server.tag)
    assert(server.enabled)
    assert_nil(server.state)
    assert_equal(2, server.load)
  end

  test 'Server find_available with required tag raises error with specific message if no matching tagged server available' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 2, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          tag: 'wrong-tag', enabled: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 1, 'test-2')
    end

    assert_raises(BBBErrors::ServerTagUnavailableError) do
      Server.find_available('test-tag!')
    end
  end

  test 'Servers load are retained after being cordoned' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 5, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 5, 'test-2')
    end

    Server.all.each do |server|
      server.state = 'cordoned'
      server.save!
    end

    Server.all.each do |server|
      assert_equal(server.state, 'cordoned')
      assert_equal(5, server.load)
    end
  end

  test 'Servers load are removed after changing state to disabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 5, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 5, 'test-2')
    end

    Server.all.each do |server|
      server.state = 'disabled'
      server.save!
    end

    Server.all.each do |server|
      assert_equal(server.state, 'disabled')
      assert_nil(server.load)
    end
  end

  test 'Servers load are removed after changing enabled to disabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 5, 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 5, 'test-2')
    end

    Server.all.each do |server|
      server.enabled = false
      server.save!
    end
    Server.all.each do |server|
      assert_equal(false, server.enabled)
      assert_nil(server.load)
    end
  end

  test 'Server all with no servers' do
    servers = Server.all
    assert_empty(servers)
  end

  test 'Server all returns all servers' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          state: 'cordoned')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('cordoned_server_load', 2, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret',
                                          enabled: true)
    end

    servers = Server.all
    assert_equal(2, servers.length)
    assert_not_equal(servers[0].id, servers[1].id)
    servers.each do |server|
      case server.id
      when 'test-1'
        assert_equal('https://test-1.example.com/bigbluebutton/api', server.url)
        assert_equal('test-1-secret', server.secret)
        assert(server.state.eql?('enabled'))
        assert_nil(server.load)
      when 'test-2'
        assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
        assert_equal('test-2-secret', server.secret)
        assert_equal(server.state, 'cordoned')
        assert_equal(2, server.load)
      when 'test-3'
        assert_equal('https://test-3.example.com/bigbluebutton/api', server.url)
        assert_equal('test-3-secret', server.secret)
        assert_nil(server.state)
        assert(server.enabled)
        assert_nil(server.load)
      else
        flunk("Returned unexpected server #{server.id}")
      end
    end
  end

  test 'Server available returns available servers with state as enabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          state: 'cordoned')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret',
                                          state: 'cordoned')
      redis.sadd?('servers', 'test-3')
    end

    servers = Server.available
    assert_equal(1, servers.length)
    server = servers[0]
    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
    assert(server.state.eql?('enabled'))
    assert_nil(server.enabled)
    assert_equal(2, server.load)
  end

  test 'Server available returns available servers with enabled as true if state is nil' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          enabled: 'false')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret',
                                          enabled: 'true')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
      redis.mapped_hmset('server:test-3', url: 'https://test-3.example.com/bigbluebutton/api', secret: 'test-3-secret',
                                          enabled: 'false')
      redis.sadd?('servers', 'test-3')
    end

    servers = Server.available
    assert_equal(1, servers.length)
    server = servers[0]
    assert_equal('test-2', server.id)
    assert_equal('https://test-2.example.com/bigbluebutton/api', server.url)
    assert_equal('test-2-secret', server.secret)
    assert(server.enabled)
    assert_equal(2, server.load)
  end

  test 'Server increment load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
      redis.zadd('server_load', 2, 'test-2')
    end

    server = Server.find('test-2')
    server.increment_load(2)
    assert_not(server.load_changed?)
    assert_equal(4, server.load)

    RedisStore.with_connection do |redis|
      assert_equal(4, redis.zscore('server_load', 'test-2'))
    end
  end

  test 'Server increment load not available' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
      redis.sadd?('servers', 'test-2')
      redis.sadd?('server_enabled', 'test-2')
    end

    server = Server.find('test-2')
    server.increment_load(2)
    assert_not(server.load_changed?)
    assert_nil(server.load)

    RedisStore.with_connection do |redis|
      assert_nil(redis.zscore('server_load', 'test-2'))
    end
  end

  test 'Server create without load' do
    server = Server.new
    server.url = 'https://test-1.example.com/bigbluebutton/api'
    server.secret = 'test-1-secret'
    server.state = 'enabled'
    server.save!
    assert_not_nil(server.id)

    RedisStore.with_connection do |redis|
      hash = redis.hgetall("server:#{server.id}")
      assert_equal('https://test-1.example.com/bigbluebutton/api', hash['url'])
      assert_equal('test-1-secret', hash['secret'])
      assert_equal('false', hash['online'])
      servers = redis.smembers('servers')
      assert_equal(1, servers.length)
      assert_equal(server.id, servers[0])
      assert(redis.sismember('server_enabled', server.id))
      servers = redis.zrange('server_load', 0, -1)
      assert_predicate(servers, :blank?)
    end
  end

  test 'Server create with load' do
    server = Server.new
    server.url = 'https://test-2.example.com/bigbluebutton/api'
    server.secret = 'test-2-secret'
    server.state = 'enabled'
    server.load = 2
    server.online = true
    server.save!
    assert_not_nil(server.id)

    RedisStore.with_connection do |redis|
      hash = redis.hgetall("server:#{server.id}")
      assert_equal('https://test-2.example.com/bigbluebutton/api', hash['url'])
      assert_equal('test-2-secret', hash['secret'])
      assert_equal('true', hash['online'])
      servers = redis.smembers('servers')
      assert_equal(1, servers.length)
      assert_equal(server.id, servers[0])
      assert(redis.sismember('server_enabled', server.id))
      servers = redis.zrange('server_load', 0, -1, with_scores: true)
      assert_equal(1, servers.length)
      assert_equal(server.id, servers[0][0])
      assert_equal(2, servers[0][1])
    end
  end

  test 'Server create id is UUID' do
    Rails.configuration.x.stub(:server_id_is_hostname, false) do
      server = Server.new
      server.url = 'https://test.example.com/bigbluebutton/api'
      server.secret = 'test-secret'
      server.enabled = false
      server.save!

      assert_match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/, server.id)
    end
  end

  test 'Server create id is hostname' do
    Rails.configuration.x.stub(:server_id_is_hostname, true) do
      server1 = Server.new
      server1.url = 'https://test.example.com/bigbluebutton/api'
      server1.secret = 'test-secret'
      server1.enabled = false
      server1.save!

      assert_equal('test.example.com', server1.id)

      server2 = Server.new
      server2.url = 'https://TEST.example.CoM/bigbluebutton/api'
      server2.secret = 'test2-secret'
      server2.enabled = false
      assert_raises(ApplicationRedisRecord::RecordNotSaved) do
        server2.save!
      end
    end
  end

  test 'Server update id' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
    end

    server = Server.find('test-1')
    server.id = 'test-2'
    assert_raises(ApplicationRedisRecord::RecordNotSaved) do
      server.save!
    end
  end

  test 'Server update url' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
    end

    server = Server.find('test-1')
    server.url = 'https://test-2.example.com/bigbluebutton/api'
    server.save!

    RedisStore.with_connection do |redis|
      hash = redis.hgetall('server:test-1')
      assert_equal('https://test-2.example.com/bigbluebutton/api', hash['url'])
      assert_equal('test-1-secret', hash['secret'])
    end
  end

  test 'Server update secret' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
    end

    server = Server.find('test-1')
    server.secret = 'test-2-secret'
    server.save!

    RedisStore.with_connection do |redis|
      hash = redis.hgetall('server:test-1')
      assert_equal('https://test-1.example.com/bigbluebutton/api', hash['url'])
      assert_equal('test-2-secret', hash['secret'])
    end
  end

  test 'Server update load (from nil)' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
    end

    server = Server.find('test-1')
    server.load = 1
    server.save!

    RedisStore.with_connection do |redis|
      load = redis.zscore('server_load', 'test-1')
      assert_equal(1, load)
    end
  end

  test 'Server update load (to nil)' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
    end

    server = Server.find('test-1')
    server.load = nil
    server.save!

    RedisStore.with_connection do |redis|
      load = redis.zscore('server_load', 'test-1')
      assert_nil(load)
    end
  end

  test 'Server update load' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
    end

    server = Server.find('test-1')
    server.load = 2
    server.save!

    RedisStore.with_connection do |redis|
      load = redis.zscore('server_load', 'test-1')
      assert_equal(2, load)
    end
  end

  test 'Server update load disabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'disabled')
      redis.sadd?('servers', 'test-1')
    end

    server = Server.find('test-1')
    server.load = 2
    server.save!
    assert_nil(server.load)

    RedisStore.with_connection do |redis|
      assert_nil(redis.zscore('server_load', 'test-1'))
    end
  end

  test 'Server update online' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          online: 'false', state: 'enabled')
      redis.sadd?('servers', 'test-1')
    end

    server = Server.find('test-1')
    assert_not(server.online)
    server.online = true
    server.save!

    RedisStore.with_connection do |redis|
      hash = redis.hgetall('server:test-1')
      assert_equal('true', hash['online'])
    end
  end

  test 'Server disable' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                                          state: 'enabled')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
    end

    server = Server.find('test-1')
    server.state = 'disabled'
    server.save!

    assert_nil(server.load)

    RedisStore.with_connection do |redis|
      assert_not(redis.sismember('server_enabled', 'test-1'))
      assert_nil(redis.zscore('server_load', 'test-1'))
    end
  end

  test 'Server enable' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
    end

    server = Server.find('test-1')
    server.state = 'enabled'
    server.load = 2
    server.save!

    RedisStore.with_connection do |redis|
      assert(redis.sismember('server_enabled', 'test-1'))
      assert_equal(2, redis.zscore('server_load', 'test-1'))
    end
  end

  test 'Server destroy active' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
    end

    server = Server.find('test-1')
    server.destroy!

    RedisStore.with_connection do |redis|
      assert_empty(redis.hgetall('server:test1'))
      assert_not(redis.sismember('servers', 'test-1'))
      assert_not(redis.sismember('server_enabled', 'test-1'))
      assert_nil(redis.zscore('server_load', 'test-1'))
    end
  end

  test 'Server destroy unavailable' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
      redis.sadd?('server_enabled', 'test-1')
    end

    server = Server.find('test-1')
    server.destroy!

    RedisStore.with_connection do |redis|
      assert_empty(redis.hgetall('server:test1'))
      assert_not(redis.sismember('servers', 'test-1'))
      assert_not(redis.sismember('server_enabled', 'test-1'))
      assert_nil(redis.zscore('server_load', 'test-1'))
    end
  end

  test 'Server destroy disabled' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
    end

    server = Server.find('test-1')
    server.destroy!

    RedisStore.with_connection do |redis|
      assert_empty(redis.hgetall('server:test1'))
      assert_not(redis.sismember('servers', 'test-1'))
      assert_not(redis.sismember('server_enabled', 'test-1'))
      assert_nil(redis.zscore('server_load', 'test-1'))
    end
  end

  test 'Server destroy with pending changes' do
    RedisStore.with_connection do |redis|
      redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
      redis.sadd?('servers', 'test-1')
      redis.zadd('server_load', 1, 'test-1')
    end

    server = Server.find('test-1')
    server.secret = 'test-2'
    assert_raises(ApplicationRedisRecord::RecordNotDestroyed) do
      server.destroy!
    end
  end

  test 'Server destroy with non-persisted object' do
    server = Server.new(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
    assert_raises(ApplicationRedisRecord::RecordNotDestroyed) do
      server.destroy!
    end
  end

  test 'Server increment healthy increments by 1' do
    server = Server.new(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')

    assert server.healthy_counter.nil?
    assert_equal(server.increment_healthy, 1)
  end

  test 'Server increment unhealthy increments by 1' do
    server = Server.new(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')

    assert server.unhealthy_counter.nil?
    assert_equal(server.increment_unhealthy, 1)
  end

  test 'Server reset counters sets both healthy and unhealthy to 0' do
    server = Server.new(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')

    assert_equal(server.increment_healthy, 1)
    assert_equal(server.increment_unhealthy, 1)
    server.reset_counters
    assert server.healthy_counter.nil?
    assert server.unhealthy_counter.nil?
  end
end
