# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantSettings, redis: true do
  describe 'validators' do
    let(:tenant) { create :tenant }
    let(:ts) { build :tenant_settings, tenant: tenant }

    it 'has valid factory' do
      expect(ts).to be_valid
    end

    context 'with incorrect params' do
      it 'is invalid without a name' do
        ts.name = ''
        expect(ts).to_not be_valid
      end

      it 'is invalid without a value' do
        ts.value = nil
        expect(ts).to_not be_valid
      end
    end

    describe '#validate_name' do
      context 'without whitelisted setting name' do
        let(:ts) { build :tenant_settings, tenant: tenant, name: 'unsupported_name' }

        it 'throws an error' do
          expect(ts).to_not be_valid
        end
      end
    end
  end
end
