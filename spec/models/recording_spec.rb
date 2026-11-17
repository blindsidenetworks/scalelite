# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Recording do
  include TestHelper

  describe 'recording id prefixes' do
    context 'empty list' do
      let!(:recording) { create(:recording) }
      let(:rs) { described_class.with_recording_id_prefixes([]) }

      it 'is empty' do
        expect(rs).to be_empty
      end
    end

    context 'with prefixes present' do
      let(:meeting_id) { 'prefix-meeting-id' }

      let(:record_id_prefix) { Digest::SHA256.hexdigest(meeting_id) }
      let(:rs) { described_class.with_recording_id_prefixes([record_id_prefix]) }

      let!(:meeting_id_recordings) { create_list(:recording, 2, meeting_id: meeting_id) }
      let!(:not_matching_recording) { create(:recording) }

      it 'creates right amount of records' do
        expect(rs.size).to eq meeting_id_recordings.size
      end

      it 'creates all meetings with right meeting id' do
        incorrect_meetings = rs.reject { |r| r.meeting_id == meeting_id }

        expect(incorrect_meetings).to be_empty
      end
    end

    context 'with multiple recording id prefixes' do
      let(:meeting_id_a) { 'prefix-meeting-id-a' }
      let(:meeting_id_b) { 'prefix-meeting-id-b' }
      let(:record_id_prefix_a) { Digest::SHA256.hexdigest(meeting_id_a) }
      let(:record_id_prefix_b) { Digest::SHA256.hexdigest(meeting_id_b) }

      let!(:recordings_a) { create_list(:recording, 2, meeting_id: meeting_id_a) }
      let!(:recordings_b) { create_list(:recording, 3, meeting_id: meeting_id_b) }

      let(:rs) { described_class.with_recording_id_prefixes([record_id_prefix_a, record_id_prefix_b]) }

      it 'creates proper number of recordings total' do
        expect(rs.size).to eq(recordings_a.size + recordings_b.size)
      end

      it 'creates proper number of recordings for A' do
        rs_meeting_a = rs.select { |r| r.meeting_id == meeting_id_a }

        expect(rs_meeting_a.size).to eq recordings_a.size
      end

      it 'creates proper number of recordings for B' do
        rs_meeting_b = rs.select { |r| r.meeting_id == meeting_id_b }

        expect(rs_meeting_b.size).to eq recordings_b.size
      end
    end
  end

  describe '#key_prefix' do
    let(:recording) { create(:recording) }

    context 'when S3_RECORDING_TENANT_PREFIX is not set' do
      it 'returns an empty prefix' do
        expect(recording.key_prefix).to eq('')
      end
    end

    context 'when S3_RECORDING_TENANT_PREFIX is set' do
      it 'returns the tenant name as a prefix when the recording has a tenant' do
        mock_env("S3_RECORDING_TENANT_PREFIX" => "true") do
          tenant = create(:tenant)
          create(:metadatum, recording: recording, key: 'tenant-id', value: tenant.id)

          expect(recording.key_prefix).to eq("#{tenant.name}/")
        end
      end
    end
  end
end
