# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tenant, redis: true do
  describe 'validators' do
    let(:tenant) { build(:tenant) }

    it 'has valid factory' do
      expect(tenant).to be_valid
    end

    context 'with incorrect params' do
      it 'is invalid without a name' do
        tenant.name = ''
        expect(tenant).not_to be_valid
      end

      it 'is invalid without a secret' do
        tenant.secrets = ''
        expect(tenant).not_to be_valid
      end

      context 'with duplicating attributes' do
        it 'is invalid with duplicating name' do
          described_class.create(name: tenant.name, secrets: 'uniq secret')

          expect(tenant).not_to be_valid
        end

        it 'is invalid with duplicating secret' do
          described_class.create(name: 'uniq name', secrets: tenant.secrets)

          expect(tenant).not_to be_valid
        end
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
      let(:nb_of_secrets) { rand(3..10) }
      let(:secrets_array) { [] }
      let(:tenant) { build(:tenant) }

      before do
        nb_of_secrets.times do
          hash = Faker::Crypto.sha512
          secrets_array << hash
        end
        secrets_string = secrets_array.join(Tenant::SECRETS_SEPARATOR)

        tenant.update(secrets: secrets_string)
      end

      it 'returns correct number of elements' do
        expect(tenant.secrets_array.size).to eq nb_of_secrets
      end

      it 'contains all the elements' do
        tenant.secrets_array.each do |tenant_secret|
          expect(secrets_array).to include tenant_secret
        end
      end
    end
  end
end
