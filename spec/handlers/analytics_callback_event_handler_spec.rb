# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventHandler do
  describe '#handle' do
    context 'when meta_analytics-callback-url is present' do
      it 'creates record in CallbackData' do
        params = { 'meta_analytics-callback-url' => 'https://test-1.example.com/' }
        described_class.new(params, 'test-123').handle
        callbackdata = CallbackData.find_by(meeting_id: 'test-123')
        expect(callbackdata.callback_attributes[:analytics_callback_url]).to eq('https://test-1.example.com/')
      end
    end

    context 'when meta_analytics-callback-url is nil' do
      it 'does not create record in CallbackData' do
        params = { 'meta_analytics-callback-url' => nil }
        described_class.new(params, 'test-123').handle
        callbackdata = CallbackData.find_by(meeting_id: 'test-123')
        expect(callbackdata).to be_nil
      end
    end

    context 'multitenancy' do
      let!(:tenant) { create(:tenant, name: 'bn') }

      before do
        Rails.configuration.x.multitenancy_enabled = true
      end

      it 'makes the callback to the specific tenant' do
        params = { 'meta_analytics-callback-url' => 'https://test-1.example.com/' }
        described_class.new(params, 'test-123', tenant).handle
        expect(params['meta_analytics-callback-url']).to eq("https://#{tenant.name}.#{Rails.configuration.x.url_host}/bigbluebutton/api/analytics_callback")
      end
    end
  end
end
