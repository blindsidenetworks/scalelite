# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tenant, redis: true do
  describe '.find' do
    context 'with non-existent id' do
      it 'raises error' do
        expect {
          described_class.find('non-existent-id')
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with correct id' do
      let(:tenant) { create(:tenant) }

      it 'has proper settings' do
        ten = described_class.find(tenant.id)
        expect(ten.id).to eq tenant.id
        expect(ten.name).to eq tenant.name
        expect(ten.secrets).to eq tenant.secrets
      end
    end
  end

  describe '.secrets_array' do
    context 'with single secret' do
      let(:secret) { Faker::Crypto.sha512 }
      let(:tenant) { build_stubbed(:tenant, secrets: secret) }

      it 'returns one element' do
        expect(tenant.secrets_array.class).to eq Array
        expect(tenant.secrets_array.size).to eq 1
        expect(tenant.secrets_array).to include secret
      end
    end

    context 'with multiple secrets' do
      let(:secrets_string) { '123:abc:1ac' }
      let(:tenant) { create(:tenant, secrets: secrets_string) }

      it 'returns correct number of elements' do
        expect(tenant.secrets_array.size).to eq secrets_string.split(':').count
      end

      it 'contains all the elements' do
        expect(tenant.secrets_array).to eq secrets_string.split(':')
      end
    end
  end
end
