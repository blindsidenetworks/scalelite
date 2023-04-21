# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Meeting, redis: true do
  describe '.find' do
    context 'with non-existent ID' do
      it 'raises proper exception' do
        expect {
          Meeting.find('non-existent-id')
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with no server' do
      let(:meeting) { Meeting.find('test-meeting-1') }
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
        end
      end

      it 'sets correct server_id' do
        expect(meeting.server_id).to eq 'test-server-1'
      end

      it 'raises proper error' do
        expect {
          meeting.server
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with server' do
      let(:meeting) { Meeting.find('test-meeting-1') }
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
          redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
        end
      end

      it 'creates correct server' do
        expect(meeting.server_id).to eq 'test-server-1'

        server = meeting.server
        expect(server.id).to eq 'test-server-1'
      end

      describe 'multitenancy' do
        context 'with multiple tenants' do
          let(:tenant1) { create(:tenant) }
          let(:tenant2) { create(:tenant) }

          let(:meeting1) { Meeting.find 'test-meeting-1', tenant1.id }
          let(:fetching_wrong_meeting) { Meeting.find 'test-meeting-1', tenant2.id }

          before do
            RedisStore.with_connection do |redis|
              redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1', tenant_id: tenant1.id)
              redis.mapped_hmset('meeting:test-meeting-2', server_id: 'test-server-1', tenant_id: tenant2.id)
              redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
            end
          end

          it 'returns correct tenant\'s Meeting' do
            expect(meeting1).to be_present
          end

          it 'does not fetch meeting with incorrect id/tenant_id' do
            expect {
              fetching_wrong_meeting
            }.to raise_error(ApplicationRedisRecord::RecordNotFound)
          end
        end

        context 'without tenant' do
          let(:tenant1) { create(:tenant) }
          let(:meeting_with_tenant) { Meeting.find 'test-meeting-1', tenant1.id }
          let(:meeting_without_tenant) { Meeting.find 'test-meeting-1' }

          before do
            RedisStore.with_connection do |redis|
              redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
              redis.mapped_hmset('meeting:test-meeting-2', server_id: 'test-server-1', tenant_id: tenant1.id)
              redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
            end
          end

          it 'returns only Meeting with empty tenant_id' do
            expect(Meeting.find('test-meeting-1')).to be_present
          end

          it 'throws error when trying to fetch existing Meeting providing incorrect Tenant' do
            expect {
              Meeting.find 'test-meeting-1', tenant1.id
            }.to raise_error(ApplicationRedisRecord::RecordNotFound)
          end
        end
      end
    end
  end

  describe '.all' do
    context 'with multiple meetings' do
      let(:all_meetings) { Meeting.all }

      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
          redis.mapped_hmset('meeting:test-meeting-2', server_id: 'test-server-2')
          redis.sadd?('meetings', %w[test-meeting-1 test-meeting-2])
        end
      end

      it 'creates both meetings' do
        expect(all_meetings.size).to eq 2
      end

      it 'creates different meetings' do
        expect(all_meetings[0].id).to_not eq all_meetings[1].id
      end
    end

    describe 'multitenancy' do
      let(:tenant1) { create(:tenant) }
      let(:tenant2) { create(:tenant) }

      before do
        RedisStore.with_connection do |redis|
          # Meetings with no tenant
          redis.mapped_hmset('meeting:test-meeting-01', server_id: 'test-server-1')
          redis.mapped_hmset('meeting:test-meeting-02', server_id: 'test-server-1')
          # Meetings with Tenant1
          redis.mapped_hmset('meeting:test-meeting-11', server_id: 'test-server-1', tenant_id: tenant1.id)
          redis.mapped_hmset('meeting:test-meeting-12', server_id: 'test-server-1', tenant_id: tenant1.id)
          redis.mapped_hmset('meeting:test-meeting-13', server_id: 'test-server-1', tenant_id: tenant1.id)
          # Meetings with Tenant2
          redis.mapped_hmset('meeting:test-meeting-21', server_id: 'test-server-1', tenant_id: tenant2.id)
          redis.mapped_hmset('meeting:test-meeting-22', server_id: 'test-server-1', tenant_id: tenant2.id)

          # server
          redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')

          redis.sadd?('meetings', %w[test-meeting-01 test-meeting-02
                                     test-meeting-11 test-meeting-12 test-meeting-13
                                     test-meeting-21 test-meeting-22])
        end
      end

      context 'with tenant_id param' do
        let(:meetings) { Meeting.all(tenant1.id) }

        it 'fetches correct nb of Meetings' do
          expect(meetings.size).to eq 3
        end

        it 'fetches Meetings with correct tenant_id' do
          meetings.each do |meeting|
            expect(meeting.tenant_id.to_i).to eq tenant1.id
          end
        end
      end

      context 'without tenant_id param' do
        let(:meetings) { Meeting.all }

        it 'fetches correct nb of Meetings' do
          expect(meetings.size).to eq 2
        end

        it 'fetches Meetings with correct tenant_id' do
          meetings.each do |meeting|
            expect(meeting.tenant_id).to be_nil
          end
        end
      end
    end
  end

  describe '.create' do
    let(:server) { Server.find('test-server-1') }

    before do
      RedisStore.with_connection do |redis|
        redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
        redis.sadd?('servers', 'test-server-1')
      end
    end

    it 'creates meeting' do
      meeting = Meeting.new
      meeting.id = 'Demo Meeting'
      meeting.server = server
      meeting.save!

      RedisStore.with_connection do |redis|
        expect(redis.sismember('meetings', 'Demo Meeting')).to be true

        meeting_hash = redis.hgetall('meeting:Demo Meeting')
        expect(meeting_hash['server_id']).to eq 'test-server-1'
      end
    end

    context 'atomic create (new meeting)' do
      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
          redis.sadd?('servers', 'test-server-1')
          redis.mapped_hmset('server:test-server-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
          redis.sadd?('servers', 'test-server-2')
          redis.mapped_hmset('meeting:Demo Meeting', server_id: 'test-server-1')
          redis.sadd?('meetings', 'Demo Meeting')
        end
      end

      it 'creates correct meeting' do
        meeting = Meeting.find('Demo Meeting')
        expect(meeting.server_id).to eq 'test-server-1'

        server = Server.find('test-server-2')
        meeting = Meeting.find_or_create_with_server('Demo Meeting', server, 'mp')

        expect(meeting.id).to eq 'Demo Meeting'
        expect(meeting.server).to_not eq server
        expect(meeting.server_id).to eq 'test-server-1'

        RedisStore.with_connection do |redis|
          expect(redis.sismember('meetings', 'Demo Meeting')).to eq true

          meeting_hash = redis.hgetall('meeting:Demo Meeting')
          expect(meeting_hash['server_id']).to eq 'test-server-1'
        end
      end
    end
  end

  describe '#update' do
    let(:meeting) { Meeting.find('test-meeting-1') }

    before do
      RedisStore.with_connection do |redis|
        redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
        redis.sadd?('servers', 'test-server-1')
        redis.mapped_hmset('server:test-server-2', url: 'https://test-2.example.com/bigbluebutton/api', secret: 'test-2')
        redis.sadd?('servers', 'test-server-2')
        redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
        redis.sadd?('meetings', 'test-meeting-1')
      end
    end

    it 'sets correct values before update' do
      expect(meeting.server_id).to eq 'test-server-1'
      expect(meeting.server.id).to eq 'test-server-1'
    end

    it 'updates server_id' do
      meeting.server_id = 'test-server-2'
      meeting.save!

      RedisStore.with_connection do |redis|
        meeting_hash = redis.hgetall('meeting:test-meeting-1')
        expect(meeting_hash['server_id']).to eq 'test-server-2'
      end
    end

    it 'updates server' do
      meeting.server = Server.find('test-server-2')
      meeting.save!

      RedisStore.with_connection do |redis|
        meeting_hash = redis.hgetall('meeting:test-meeting-1')
        expect(meeting_hash['server_id']).to eq 'test-server-2'
      end
    end
  end

  describe '#destroy' do
    let(:meeting) { Meeting.find('test-meeting-1') }
    before do
      RedisStore.with_connection do |redis|
        redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
        redis.sadd?('servers', 'test-server-1')
        redis.mapped_hmset('meeting:test-meeting-1', server_id: 'test-server-1')
        redis.sadd?('meetings', 'test-meeting-1')
      end
    end

    it 'successfully destroys object' do
      meeting.destroy!

      RedisStore.with_connection do |redis|
        expect(redis.sismember('meetings', 'test-meeting-1')).to eq false

        redis_entry = redis.hgetall('meeting:test-meeting-1')
        expect(redis_entry).to eq({})
      end
    end

    context 'with pending changes' do
      before do
        meeting.server_id = 'test-server-2'
      end

      it 'throws an error' do
        expect {
          meeting.destroy!
        }.to raise_error(ApplicationRedisRecord::RecordNotDestroyed)
      end
    end

    context 'with non-persisted object' do
      let(:meeting) { Meeting.new }
      let(:server) { Server.find('test-server-1') }

      before do
        RedisStore.with_connection do |redis|
          redis.mapped_hmset('server:test-server-1', url: 'https://test-1.example.com/bigbluebutton/api', secret: 'test-1')
          redis.sadd?('servers', 'test-server-1')
        end

        meeting.server = server
      end

      it 'throws an error' do
        expect {
          meeting.destroy!
        }.to raise_error(ApplicationRedisRecord::RecordNotDestroyed)
      end
    end
  end
end
