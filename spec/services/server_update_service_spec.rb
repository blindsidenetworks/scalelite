# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ServerUpdateService, type: :service do
  describe '#call' do
    context 'when updating state' do
      it 'enables the server' do
        server = create(:server)
        service = described_class.new(server, { state: 'enable' })
        service.call
        server = Server.find(server.id) # Reload
        expect(server.state).to eq('enabled')
      end

      it 'cordons the server' do
        server = create(:server)
        service = described_class.new(server, { state: 'cordon' })
        service.call
        server = Server.find(server.id) # Reload
        expect(server.state).to eq('cordoned')
      end

      it 'disables the server' do
        server = create(:server)
        service = described_class.new(server, { state: 'disable' })
        service.call
        server = Server.find(server.id) # Reload
        expect(server.state).to eq('disabled')
      end

      it 'raises an error for an invalid state' do
        server = create(:server)
        service = described_class.new(server, { state: 'invalid_state' })
        expect { service.call }.to raise_error(ArgumentError, "Invalid state parameter: invalid_state")
      end
    end

    context 'when updating load_multiplier' do
      it 'updates the load_multiplier' do
        server = create(:server)
        service = described_class.new(server, { load_multiplier: 2.5 })
        service.call
        server = Server.find(server.id) # Reload
        expect(server.load_multiplier).to eq("2.5")
      end

      it 'raises an error for a zero load_multiplier' do
        server = create(:server)
        service = described_class.new(server, { load_multiplier: 0 })
        expect { service.call }.to raise_error(ArgumentError, "Load-multiplier must be a non-zero number")
      end
    end

    context 'when updating both state and load_multiplier' do
      it 'updates both state and load_multiplier' do
        server = create(:server)
        service = described_class.new(server, { state: 'cordon', load_multiplier: 2.5 })
        service.call
        server = Server.find(server.id) # Reload
        expect(server.state).to eq('cordoned')
        expect(server.load_multiplier).to eq("2.5")
      end
    end
  end
end
