# frozen_string_literal: true

require 'test_helper'

class PlaybackControllerTest < ActionDispatch::IntegrationTest
  test 'should get playback' do
    recording = create(:recording)
    get "/playback/presentation/2.0/#{recording.record_id}"
    assert_response :success
  end
end
