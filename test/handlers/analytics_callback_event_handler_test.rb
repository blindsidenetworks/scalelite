# frozen_string_literal: true

class AnalyticsCallbackEventHandlerTest < ActiveSupport::TestCase
  require 'test_helper'

  test 'creates record in CallbackData' do
    params = { 'meta_analytics-callback-url' => 'https://test-1.example.com/' }
    EventHandler.new(params, 'test-123').handle
    callbackdata = CallbackData.find_by_meeting_id('test-123')
    assert_equal callbackdata.callback_attributes[:analytics_callback_url], 'https://test-1.example.com/'
  end

  test 'does not create record in CallbackData if meta_analytics-callback-url is nil' do
    params = { 'meta_analytics-callback-url' => nil }
    EventHandler.new(params, 'test-123').handle
    callbackdata = CallbackData.find_by_meeting_id('test-123')
    assert_nil callbackdata
  end
end
