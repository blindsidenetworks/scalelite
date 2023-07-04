# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RecordingReadyNotifierService, type: :service do
  before do
    Rails.configuration.x.multitenancy_enabled = false
  end

  let!(:recording) { create(:recording) }
  let(:url) { 'https://test-1.example.com/bigbluebutton/api/' }
  let!(:callback_data) do
    create(:callback_data,
           meeting_id: recording.meeting_id,
           recording_id: recording.id,
           callback_attributes: { recording_ready_url: 'https://test-1.example.com/bigbluebutton/api/' })
  end

  it 'returns true if recording ready notification succeeds' do
    stub_request(:post, url)
      .to_return(status: 200, body: '', headers: {})

    allow(JWT).to receive(:encode).and_return('eyJhbGciOiJIUzI1NiJ9.eyJtZWV0aW5nX2lkIjoibWVldGluZzE5In0.Jlw1ND63QJ3j9TT0mgp_5fpmPA82FhMT_-mPU25PEFY')
    return_val = described_class.execute(recording.id)

    expect(return_val).to be true
  end

  it 'returns false if recording ready notification fails' do
    stub_request(:post, url).to_timeout

    allow(JWT).to receive(:encode).and_return('eyJhbGciOiJIUzI1NiJ9.eyJtZWV0aW5nX2lkIjoibWVldGluZzE5In0.Jlw1ND63QJ3j9TT0mgp_5fpmPA82FhMT_-mPU25PEFY')
    return_val = described_class.execute(recording.id)

    expect(return_val).to be false
  end

  context 'multitenancy' do
    let!(:tenant) { create(:tenant, name: 'bn') }

    before do
      Rails.configuration.x.multitenancy_enabled = true
      create(:metadatum, recording: recording, key: 'tenant-id', value: tenant.id)
    end

    it 'encodes the payload using the tenants secret' do
      stub_request(:post, url)
        .to_return(status: 200, body: '', headers: {})

      expect(JWT).to receive(:encode).with({ meeting_id: recording.meeting_id, record_id: recording.record_id }, tenant.secrets_array[0])

      described_class.execute(recording.id)
    end
  end
end
