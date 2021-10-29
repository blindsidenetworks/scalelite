# frozen_string_literal: true

require 'test_helper'

class RecordingTest < ActiveSupport::TestCase
  test 'with recording id prefixes empty list' do
    create(:recording)

    rs = Recording.with_recording_id_prefixes([])
    assert_empty(rs)
  end

  test 'with recording id prefixes' do
    meeting_id = 'prefix-meeting-id'

    # Matching recordings
    create(:recording, meeting_id: meeting_id)
    create(:recording, meeting_id: meeting_id)

    # Not matching
    create(:recording)

    record_id_prefix = Digest::SHA256.hexdigest(meeting_id)

    rs = Recording.with_recording_id_prefixes([record_id_prefix])
    assert_equal(2, rs.length)
    # Make sure all meetings have the right meeting id
    assert_empty(rs.reject { |r| r.meeting_id == meeting_id })
  end

  test 'with multiple recording id prefixes' do
    meeting_id_a = 'prefix-meeting-id-a'
    meeting_id_b = 'prefix-meeting-id-b'

    # Matching recordings
    create(:recording, meeting_id: meeting_id_a)
    create(:recording, meeting_id: meeting_id_a)
    create(:recording, meeting_id: meeting_id_b)
    create(:recording, meeting_id: meeting_id_b)

    # Not matching
    create(:recording)

    record_id_prefix_a = Digest::SHA256.hexdigest(meeting_id_a)
    record_id_prefix_b = Digest::SHA256.hexdigest(meeting_id_b)

    rs = Recording.with_recording_id_prefixes([record_id_prefix_a, record_id_prefix_b])
    assert_equal(4, rs.length)
    assert_equal(2, rs.select { |r| r.meeting_id == meeting_id_a }.length)
    assert_equal(2, rs.select { |r| r.meeting_id == meeting_id_b }.length)
  end
end
