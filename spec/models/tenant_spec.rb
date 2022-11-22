# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tenant, redis: true do
  describe 'validators' do
    let(:tenant) { build :tenant }

    it 'has valid factory' do
      expect(tenant).to be_valid
    end

    context 'with incorrect params' do
      it 'is invalid without a name' do
        tenant.name = ''
        expect(tenant).to_not be_valid
      end

      it 'is invalid without a secret' do
        tenant.secrets = ''
        expect(tenant).to_not be_valid
      end

      context 'with duplicating attributes' do
        it 'is invalid with duplicating name' do
          Tenant.create(name: tenant.name, secrets: 'uniq secret')

          expect(tenant).to_not be_valid
        end

        it 'is invalid with duplicating secret' do
          Tenant.create(name: 'uniq name', secrets: tenant.secrets)

          expect(tenant).to_not be_valid
        end
      end
    end
  end
end
