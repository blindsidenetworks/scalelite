# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Server, redis: true do
  describe '.find' do
    context 'with non-existent id' do
      it 'raises error' do
        expect {
          described_class.find('non-existent-id')
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with no load' do
      let(:server) { described_class.find('test-1') }

      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
          redis.sadd?('servers', 'test-1')
          redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
          redis.sadd?('servers', 'test-2')
        end
      end

      it 'has proper settings' do
        expect(server.id).to eq 'test-1'
        expect(server.url).to eq 'https://test-1.example.com/bigbluebutton/api'
        expect(server.enabled).to be false
        expect(server.load).to be_nil
        expect(server.online).to be false
      end
    end

    context 'with load' do
      let(:server) { described_class.find('test-2') }

      before do
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
      end

      it 'has proper settings' do
        expect(server.id).to eq 'test-2'
        expect(server.url).to eq 'https://test-2.example.com/bigbluebutton/api'
        expect(server.secret).to eq 'test-2-secret'
        expect(server.enabled).to be true
        expect(server.state).to be_nil
        expect(server.load).to eq 2
        expect(server.online).to be true
      end
    end

    context 'with load and state as enabled' do
      let(:server) { described_class.find('test-2') }

      before do
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
      end

      it 'has proper settings' do
        expect(server.id).to eq 'test-2'
        expect(server.url).to eq 'https://test-2.example.com/bigbluebutton/api'
        expect(server.secret).to eq 'test-2-secret'
        expect(server.enabled).to be_nil
        expect(server.state).to eq 'enabled'
        expect(server.load).to eq 2
        expect(server.online).to be true
      end
    end

    context 'disabled' do
      context 'when disabled' do
        let(:server) { described_class.find('test-2') }

        before do
          RedisStore.with_connection do |redis|
            redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
            redis.sadd?('servers', 'test-1')
            redis.sadd?('server_enabled', 'test-1')
            redis.zadd('server_load', 1, 'test-1')
            redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
            redis.sadd?('servers', 'test-2')
          end
        end

        it 'has proper settings' do
          expect(server.id).to eq 'test-2'
          expect(server.url).to eq 'https://test-2.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-2-secret'
          expect(server.state).to be_nil
          expect(server.enabled).to be false
          expect(server.load).to be_nil
        end
      end

      context 'with state as disabled' do
        let(:server) { described_class.find('test-2') }

        before do
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
        end

        it 'has proper settings' do
          expect(server.id).to eq 'test-2'
          expect(server.url).to eq 'https://test-2.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-2-secret'
          expect(server.state).to eq 'disabled'
          expect(server.enabled).to be_nil
          expect(server.load).to be_nil
        end
      end
    end
  end

  describe '.find_available' do
    context 'with no available servers' do
      it 'throws an error' do
        expect {
          described_class.find_available
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with any tag and no available servers' do
      it 'throws an error' do
        expect {
          described_class.find_available('test-tag')
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with missing server hash' do
      before do
        # This is mostly a failsafe check
        RedisStore.with_connection do |redis|
          redis.zadd('server_load', 0, 'test-id')
        end
      end

      it 'raises error' do
        expect {
          # Protection against infinite loops
          Timeout.timeout(1) do
            described_class.find_available
          end
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'returns server' do
      let(:server) { described_class.find_available }

      before do
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
      end

      it 'returns server with lowest load' do
        expect(server.id).to eq 'test-1'
        expect(server.url).to eq 'https://test-1.example.com/bigbluebutton/api'
        expect(server.secret).to eq 'test-1-secret'
        expect(server.enabled).to be true
        expect(server.state).to be_nil
        expect(server.load).to eq 1
      end

      context 'with lowest load and state as enabled' do
        before do
          RedisStore.with_connection do |redis|
            redis.redis.flushall
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
        end

        it 'returns correct server' do
          expect(server.id).to eq 'test-1'
          expect(server.url).to eq 'https://test-1.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-1-secret'
          expect(server.state).to eq 'enabled'
          expect(server.enabled).to be_nil
          expect(server.load).to eq 1
        end
      end
    end

    context 'with all servers cordoned' do
      before do
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

        described_class.all.each do |server|
          server.state = 'cordoned'
          server.save!
        end
      end

      it 'raises an error' do
        expect {
          described_class.find_available
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with all servers disabled' do
      before do
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

        described_class.all.each do |server|
          server.enabled = false
          server.save!
        end
      end

      it 'raises no error' do
        expect {
          described_class.find_available
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with tagged servers' do
      before do
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
      end

      context 'and without argument' do
        let(:server) { described_class.find_available }

        it 'returns untagged server with lowest load' do
          expect(server.id).to eq 'test-3'
          expect(server.url).to eq 'https://test-3.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-3-secret'
          expect(server.tag).to be_nil
          expect(server.enabled).to be true
          expect(server.state).to be_nil
          expect(server.load).to eq 2
        end
      end

      context 'and with empty tag argument' do
        let(:server) { described_class.find_available('') }

        it 'returns untagged server with lowest load' do
          expect(server.id).to eq 'test-3'
        end
      end

      context 'and with ! tag argument' do
        let(:server) { described_class.find_available('!') }

        it 'returns untagged server with lowest load' do
          expect(server.id).to eq 'test-3'
        end
      end
    end

    context 'with differently tagged servers' do
      let(:server) { described_class.find_available('test-tag') }

      before do
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
      end

      context 'and optional tag argument' do
        let(:server) { described_class.find_available('test-tag') }

        it 'returns matching tagged server with lowest load' do
          expect(server.id).to eq 'test-3'
          expect(server.url).to eq 'https://test-3.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-3-secret'
          expect(server.tag).to eq 'test-tag'
          expect(server.enabled).to be true
          expect(server.state).to be_nil
          expect(server.load).to eq 2
        end
      end

      context 'and required tag argument' do
        let(:server) { described_class.find_available('test-tag!') }

        it 'returns matching tagged server with lowest load' do
          expect(server.id).to eq 'test-3'
          expect(server.tag).to eq 'test-tag'
        end
      end
    end

    context 'with no matching tagged servers' do
      before do
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
      end

      context 'and optional tag argument' do
        let(:server) { described_class.find_available('test-tag') }

        it 'returns untagged server with lowest load' do
          expect(server.id).to eq 'test-3'
          expect(server.url).to eq 'https://test-3.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-3-secret'
          expect(server.tag).to be_nil
          expect(server.enabled).to be true
          expect(server.state).to be_nil
          expect(server.load).to eq 2
        end
      end

      it 'raises error with specific message' do
        expect {
          described_class.find_available('test-tag!')
        }.to raise_error(ApplicationRedisRecord::RecordNotFound, "Could not find any available servers with tag=test-tag.")
      end
    end
  end

  describe 'Servers load' do
    context 'after changing state to disabled' do
      before do
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

        described_class.all.each do |server|
          server.state = 'disabled'
          server.save!
        end
      end

      it 'is removed' do
        described_class.all.each do |server|
          expect(server.state).to eq 'disabled'
          expect(server.load).to be_nil
        end
      end
    end

    context 'after changing enabled to disabled' do
      before do
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

        described_class.all.each do |server|
          server.enabled = false
          server.save!
        end
      end

      it 'is removed' do
        described_class.all.each do |server|
          expect(server.enabled).to be false
          expect(server.load).to be_nil
        end
      end
    end
  end

  describe '.all' do
    let(:servers) { described_class.all }

    before do
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
    end

    it 'creates proper server count' do
      expect(servers.size).to eq 2
    end

    it 'creates different servers' do
      expect(servers[0].id).not_to eq servers[1].id
    end

    it 'creates every server properly' do
      servers.each do |server|
        case server.id
        when 'test-1'
          expect(server.url).to eq 'https://test-1.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-1-secret'
          expect(server.state).to eq 'enabled'
          expect(server.load).to be_nil
        when 'test-2'
          expect(server.url).to eq 'https://test-2.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-2-secret'
          expect(server.state).to eq 'cordoned'
          expect(server.load).to eq 2
        when 'test-3'
          expect(server.url).to eq 'https://test-3.example.com/bigbluebutton/api'
          expect(server.secret).to eq 'test-3-secret'
          expect(server.state).to eq be_nil
          expect(server.load).to be_nil
        else
          raise("Returned unexpected server #{server.id}")
        end
      end
    end
  end

  describe '.available' do
    let(:servers) { described_class.available }

    context 'with state as enabled' do
      before do
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
      end

      it 'returns correct number of servers' do
        expect(servers.size).to eq 1
      end

      it 'returns correct server' do
        server = servers[0]

        expect(server.id).to eq 'test-2'
        expect(server.url).to eq 'https://test-2.example.com/bigbluebutton/api'
        expect(server.secret).to eq 'test-2-secret'
        expect(server.state).to eq 'enabled'
        expect(server.enabled).to be_nil
        expect(server.load).to eq 2
      end
    end

    context 'with enabled as true if state is nil' do
      before do
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
      end

      it 'returns correct number of servers' do
        expect(servers.count).to eq 1
      end

      it 'returns correct server' do
        server = servers[0]
        expect(server.id).to eq 'test-2'
        expect(server.url).to eq 'https://test-2.example.com/bigbluebutton/api'
        expect(server.secret).to eq 'test-2-secret'
        expect(server.enabled).to be true
        expect(server.load).to eq 2
      end
    end
  end

  describe 'increment load' do
    let(:server) { described_class.find('test-2') }

    context 'not available' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
          redis.sadd?('servers', 'test-2')
          redis.sadd?('server_enabled', 'test-2')
        end
        server.increment_load(2)
      end

      it 'fetches correct server' do
        expect(server.load_changed?).to be false
        expect(server.load).to be_nil
      end

      it 'sets Redis values correctly' do
        RedisStore.with_connection do |redis|
          server_load = redis.zscore('server_load', 'test-2')

          expect(server_load).to be_nil
        end
      end
    end

    context 'available' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2-secret')
          redis.sadd?('servers', 'test-2')
          redis.sadd?('server_enabled', 'test-2')
          redis.zadd('server_load', 2, 'test-2')
        end
        server.increment_load(2)
      end

      it 'fetches correct server' do
        expect(server.load_changed?).to be false
        expect(server.load).to eq 4
      end

      it 'sets Redis values correctly' do
        RedisStore.with_connection do |redis|
          server_load = redis.zscore('server_load', 'test-2')

          expect(server_load).to eq 4
        end
      end
    end
  end

  describe '.create' do
    context 'without load' do
      let(:server) {
        described_class.create(
          url: 'https://test-1.example.com/bigbluebutton/api',
          secret: 'test-1-secret',
          state: 'enabled'
        )
      }

      it 'creates server' do
        expect(server.id).not_to be_nil
      end

      it 'sets Redis data properly' do
        RedisStore.with_connection do |redis|
          hash = redis.hgetall("server:#{server.id}")
          expect(hash['url']).to eq server.url
          expect(hash['secret']).to eq server.secret
          expect(hash['online']).to eq 'false'

          servers = redis.smembers('servers')
          expect(servers.size).to eq 1
          expect(servers[0]).to eq server.id

          expect(redis.sismember('server_enabled', server.id)).to be true

          servers = redis.zrange('server_load', 0, -1)
          expect(servers.blank?).to be true
        end
      end
    end

    context 'with load' do
      let(:server) {
        described_class.create(
          url: 'https://test-2.example.com/bigbluebutton/api',
          secret: 'test-2-secret',
          state: 'enabled',
          load: 2,
          online: true
        )
      }

      it 'creates server' do
        expect(server.id).not_to be_nil
      end

      it 'sets Redis data properly' do
        RedisStore.with_connection do |redis|
          hash = redis.hgetall("server:#{server.id}")

          expect(hash['url']).to eq server.url
          expect(hash['secret']).to eq server.secret
          expect(hash['online']).to eq server.online.to_s

          servers = redis.smembers('servers')
          expect(servers.size).to eq 1
          expect(servers[0]).to eq server.id
          expect(redis.sismember('server_enabled', server.id)).to be true

          servers = redis.zrange('server_load', 0, -1, with_scores: true)
          expect(servers.size).to eq 1
          expect(servers[0][0]).to eq server.id
          expect(servers[0][1]).to eq 2
        end
      end
    end

    context 'with UUID id' do
      let(:server) {
        described_class.create(
          url: 'https://test.example.com/bigbluebutton/api',
          secret: 'test-secret',
          enabled: false
        )
      }

      before do
        allow(Rails.configuration.x).to receive(:server_id_is_hostname).and_return(false)
      end

      it 'creates correct server' do
        expect(server.id).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      end
    end

    context 'with hostname id' do
      let(:server1) {
        described_class.create(
          url: 'https://test.example.com/bigbluebutton/api',
          secret: 'test-secret',
          enabled: false
        )
      }

      let(:server2) {
        described_class.new(
          url: 'https://TEST.example.CoM/bigbluebutton/api',
          secret: 'test2-secret',
          enabled: false
        )
      }

      before do
        allow(Rails.configuration.x).to receive(:server_id_is_hostname).and_return(true)
      end

      it 'creates server1 and raises an error when trying to create server2 with the same id' do
        expect(server1.id).to eq 'test.example.com'

        expect {
          server2.save!
        }.to raise_error(ApplicationRedisRecord::RecordNotSaved)
      end
    end
  end

  describe '#update' do
    let(:server) { described_class.find('test-1') }

    before do
      RedisStore.with_connection do |redis|
        redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
        redis.sadd?('servers', 'test-1')
      end
    end

    context 'id' do
      before do
        server.id = 'test-2'
      end

      it 'raises error' do
        expect {
          server.save!
        }.to raise_error(ApplicationRedisRecord::RecordNotSaved)
      end
    end

    context 'url' do
      before do
        server.url = 'https://test-2.example.com/bigbluebutton/api'
        server.save!
      end

      it 'updates server url in Redis' do
        RedisStore.with_connection do |redis|
          hash = redis.hgetall('server:test-1')

          expect(hash['url']).to eq 'https://test-2.example.com/bigbluebutton/api'
          expect(hash['secret']).to eq server.secret
          expect(hash['url']).to eq('https://test-2.example.com/bigbluebutton/api')
          expect(hash['secret']).to eq('test-1-secret')
        end
      end
    end

    context 'secret' do
      before do
        server.secret = 'test-2-secret'
        server.save!
      end

      it 'updates server secret in Redis' do
        RedisStore.with_connection do |redis|
          hash = redis.hgetall('server:test-1')

          expect(hash['url']).to eq server.url
          expect(hash['secret']).to eq 'test-2-secret'
        end
      end
    end

    context 'load' do
      context 'load (from nil)' do
        before do
          RedisStore.with_connection do |redis|
            redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                               state: 'enabled')
            redis.sadd?('servers', 'test-1')
            redis.sadd?('server_enabled', 'test-1')
          end

          server.load = 1
          server.save!
        end

        it 'updates server load in Redis' do
          RedisStore.with_connection do |redis|
            load = redis.zscore('server_load', 'test-1')
            expect(load).to eq 1
          end
        end
      end

      context 'load (to nil)' do
        before do
          RedisStore.with_connection do |redis|
            redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                               state: 'enabled')
            redis.sadd?('servers', 'test-1')
            redis.sadd?('server_enabled', 'test-1')
            redis.zadd('server_load', 1, 'test-1')
          end

          server.load = nil
          server.save!
        end

        it 'updates server load in Redis' do
          RedisStore.with_connection do |redis|
            load = redis.zscore('server_load', 'test-1')
            expect(load).to be_nil
          end
        end
      end

      context 'load from 1 to 2' do
        before do
          RedisStore.with_connection do |redis|
            redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                               state: 'enabled')
            redis.sadd?('servers', 'test-1')
            redis.sadd?('server_enabled', 'test-1')
            redis.zadd('server_load', 1, 'test-1')
          end

          server.load = 2
          server.save!
        end

        it 'updates server load in Redis' do
          RedisStore.with_connection do |redis|
            load = redis.zscore('server_load', 'test-1')
            expect(load).to eq 2
          end
        end
      end

      context 'load for disabled server' do
        before do
          RedisStore.with_connection do |redis|
            redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                               state: 'disabled')
            redis.sadd?('servers', 'test-1')

            server.load = 2
            server.save!
          end
        end

        it 'remains nil' do
          RedisStore.with_connection do |redis|
            load = redis.zscore('server_load', 'test-1')
            expect(load).to be_nil
          end
        end
      end
    end

    context 'online' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                             online: 'false', state: 'enabled')
          redis.sadd?('servers', 'test-1')
        end
      end

      it 'puts server online' do
        expect(server.online).to be false

        server.online = true
        server.save!

        RedisStore.with_connection do |redis|
          hash = redis.hgetall('server:test-1')
          expect(hash['online']).to eq 'true'
        end
      end
    end

    context 'disable' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret',
                             state: 'enabled')
          redis.sadd?('servers', 'test-1')
          redis.sadd?('server_enabled', 'test-1')
          redis.zadd('server_load', 1, 'test-1')

          server.state = 'disabled'
          server.save!
        end
      end

      it 'sets server load to nil' do
        expect(server.load).to be_nil
      end

      it 'sets server load to nil in Redis' do
        RedisStore.with_connection do |redis|
          expect(redis.zscore('server_load', 'test-1')).to be_nil
        end
      end

      it 'sets server as disabled in Redis' do
        RedisStore.with_connection do |redis|
          expect(redis.sismember('server_enabled', 'test-1')).to be false
        end
      end
    end

    context 'enable' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
          redis.sadd?('servers', 'test-1')
        end

        server.state = 'enabled'
        server.load = 2
        server.save!
      end

      it 'sets server load to 2' do
        expect(server.load).to eq 2
      end

      it 'sets server state to enabled' do
        expect(server.state).to eq 'enabled'
      end

      it 'sets server load to 2 in Redis' do
        RedisStore.with_connection do |redis|
          expect(redis.zscore('server_load', 'test-1')).to eq 2
        end
      end

      it 'sets server as enabled in Redis' do
        RedisStore.with_connection do |redis|
          expect(redis.sismember('server_enabled', 'test-1')).to be true
        end
      end
    end
  end

  describe '#destroy' do
    let(:server) { described_class.find('test-1') }

    context 'active' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
          redis.sadd?('servers', 'test-1')
          redis.sadd?('server_enabled', 'test-1')
          redis.zadd('server_load', 1, 'test-1')
        end

        server.destroy!
      end

      it 'properly removes the server' do
        RedisStore.with_connection do |redis|
          expect(redis.hgetall('server:test1')).to be_empty
          expect(redis.sismember('servers', 'test-1')).to be false
          expect(redis.sismember('server_enabled', 'test-1')).to be false
          expect(redis.zscore('server_load', 'test-1')).to be_nil
        end
      end
    end

    context 'unavailable' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
          redis.sadd?('servers', 'test-1')
          redis.sadd?('server_enabled', 'test-1')
        end

        server.destroy!
      end

      it 'properly removes the server' do
        RedisStore.with_connection do |redis|
          expect(redis.hgetall('server:test1')).to be_empty
          expect(redis.sismember('servers', 'test-1')).to be false
          expect(redis.sismember('server_enabled', 'test-1')).to be false
          expect(redis.zscore('server_load', 'test-1')).to be_nil
        end
      end
    end

    context 'disabled' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
          redis.sadd?('servers', 'test-1')
        end

        server.destroy!
      end

      it 'properly removes the server' do
        RedisStore.with_connection do |redis|
          expect(redis.hgetall('server:test1')).to be_empty
          expect(redis.sismember('servers', 'test-1')).to be false
          expect(redis.sismember('server_enabled', 'test-1')).to be false
          expect(redis.zscore('server_load', 'test-1')).to be_nil
        end
      end
    end

    context 'with pending changes' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret')
          redis.sadd?('servers', 'test-1')
          redis.zadd('server_load', 1, 'test-1')
        end

        server.secret = 'test-2'
      end

      it 'throws an error' do
        expect {
          server.destroy!
        }.to raise_error(ApplicationRedisRecord::RecordNotDestroyed)
      end
    end

    context 'with non-persisted object' do
      let(:server) { described_class.new(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret') }

      it 'throws an error' do
        expect {
          server.destroy!
        }.to raise_error(ApplicationRedisRecord::RecordNotDestroyed)
      end
    end
  end

  describe 'increments' do
    let(:server) { described_class.new(url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1-secret') }

    context 'healthy' do
      it 'starts with nil and increments by 1' do
        expect(server.healthy_counter).to be_nil
        expect(server.increment_healthy).to eq 1
      end
    end

    context 'unhealthy' do
      it 'starts with nil and increments by 1' do
        expect(server.unhealthy_counter).to be_nil
        expect(server.increment_unhealthy).to eq 1
      end
    end

    context 'reset' do
      it 'resets counters sets both healthy and unhealthy to 0' do
        expect(server.increment_healthy).to eq 1
        expect(server.increment_unhealthy).to eq 1

        server.reset_counters

        expect(server.healthy_counter).to be_nil
        expect(server.unhealthy_counter).to be_nil
      end
    end
  end
end
