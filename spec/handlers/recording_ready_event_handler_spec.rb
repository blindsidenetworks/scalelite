# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EventHandler do
  describe '#handle' do
    context 'when meta_bn-recording-ready-url is present' do
      it 'creates record in CallbackData' do
        params = { 'meta_bn-recording-ready-url' => 'https://test-1.example.com/' }
        described_class.new(params, 'test-123').handle
        callbackdata = CallbackData.find_by(meeting_id: 'test-123')
        expect(callbackdata.callback_attributes[:recording_ready_url]).to eq('https://test-1.example.com/')
      end

      it 'returns params after removing meta_bn-recording-ready-url' do
        params = { 'meta_bn-recording-ready-url' => 'https://test-1.example.com/' }
        new_params = described_class.new(params, 'test-1234').handle
        expect(new_params).to eq({})
      end
    end

    context 'when meta_bn-recording-ready-url is nil' do
      it 'does not create record in CallbackData' do
        params = { 'meta_bn-recording-ready-url' => nil }
        described_class.new(params, 'test-123').handle
        callbackdata = CallbackData.find_by(meeting_id: 'test-123')
        expect(callbackdata).to be_nil
      end
    end
  end
end
