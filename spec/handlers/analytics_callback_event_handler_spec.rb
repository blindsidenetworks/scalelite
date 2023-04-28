# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventHandler do
  describe '#handle' do
    context 'when meta_analytics-callback-url is present' do
      it 'creates record in CallbackData' do
        params = { 'meta_analytics-callback-url' => 'https://test-1.example.com/' }
        EventHandler.new(params, 'test-123').handle
        callbackdata = CallbackData.find_by(meeting_id: 'test-123')
        expect(callbackdata.callback_attributes[:analytics_callback_url]).to eq('https://test-1.example.com/')
      end
    end

    context 'when meta_analytics-callback-url is nil' do
      it 'does not create record in CallbackData' do
        params = { 'meta_analytics-callback-url' => nil }
        EventHandler.new(params, 'test-123').handle
        callbackdata = CallbackData.find_by(meeting_id: 'test-123')
        expect(callbackdata).to be_nil
      end
    end
  end
end
