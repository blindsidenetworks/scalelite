# frozen_string_literal: true

class RecordingReadyNotifierServiceTest < ActiveSupport::TestCase
  require 'test_helper'

  test 'returns true if recording ready notification succeeds' do
    recording = create(:recording)
    url = 'https://test-1.example.com/bigbluebutton/api/'
    create(:callback_data, meeting_id: recording.meeting_id, recording_id: recording.id,
                           callback_attributes: { recording_ready_url: 'https://test-1.example.com/bigbluebutton/api/' })
    stub_request(:post, url)
      .to_return(status: 200, body: '', headers: {})

    return_val = JWT.stub(:encode, 'eyJhbGciOiJIUzI1NiJ9.eyJtZWV0aW5nX2lkIjoibWVldGluZzE5In0.Jlw1ND63QJ3j9TT0mgp_5fpmPA82FhMT_-mPU25PEFY') do # rubocop:disable LineLength
      RecordingReadyNotifierService.execute(recording.id)
    end

    assert_equal return_val, true
  end

  test 'returns false if recording ready notification fails' do
    recording = create(:recording)
    url = 'https://test-1.example.com/bigbluebutton/api/'
    create(:callback_data, meeting_id: recording.meeting_id, recording_id: recording.id,
                           callback_attributes: { recording_ready_url: 'https://test-1.example.com/bigbluebutton/api/' })

    stub_request(:post, url).to_timeout

    return_val = JWT.stub(:encode, 'eyJhbGciOiJIUzI1NiJ9.eyJtZWV0aW5nX2lkIjoibWVldGluZzE5In0.Jlw1ND63QJ3j9TT0mgp_5fpmPA82FhMT_-mPU25PEFY') do # rubocop:disable LineLength
      RecordingReadyNotifierService.execute(recording.id)
    end

    assert_equal return_val, false
  end
end
