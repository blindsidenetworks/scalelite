# frozen_string_literal: true

class RecordingReadyEventHandlerTest < ActiveSupport::TestCase
  require 'test_helper'

  test 'creates record in CallbackData' do
    params = { 'meta_bn-recording-ready-url' => 'https://test-1.example.com/' }
    EventHandler.new(params, 'test-123').handle
    callbackdata = CallbackData.find_by_meeting_id('test-123')
    assert_equal callbackdata.callback_attributes[:recording_ready_url], 'https://test-1.example.com/'
  end

  test 'does not create record in CallbackData if meta_bn-recording-ready-url is nil' do
    params = { 'meta_bn-recording-ready-url' => nil }
    EventHandler.new(params, 'test-123').handle
    callbackdata = CallbackData.find_by_meeting_id('test-123')
    assert_nil callbackdata
  end

  test 'returns params after removing meta_bn-recording-ready-url' do
    params = { 'meta_bn-recording-ready-url' => 'https://test-1.example.com/' }
    new_params = EventHandler.new(params, 'test-1234').handle
    assert_equal new_params, {}
  end
end
