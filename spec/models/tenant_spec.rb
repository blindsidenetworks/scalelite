# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tenant, :redis do
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

  describe '.find_by_name' do
    context 'with non-existent name' do
      it 'returns nil' do
        expect(
          described_class.find_by_name('non-existent-name')
        ).to be_nil
      end
    end

    context 'with correct name' do
      let(:tenant) { create(:tenant) }

      it 'has proper settings' do
        ten = described_class.find_by_name(tenant.name)
        expect(ten.id).to eq tenant.id
        expect(ten.name).to eq tenant.name
        expect(ten.secrets).to eq tenant.secrets
      end
    end
  end

  describe '.all' do
    let!(:tenants) { create_list(:tenant, 5) }

    it 'returns all of the tenants' do
      all = described_class.all
      expect(all.count).to eq(tenants.count)
      expect(all.map(&:id)).to match_array(tenants.map(&:id))
    end
  end

  describe 'recording directory' do
    it 'has none by default' do
      expect(described_class.find(create(:tenant).id).recording_dir).to be_nil
    end

    it 'stores the directory a tenant keeps its recordings in, and takes it away again' do
      tenant = create(:tenant, recording_dir: '/mnt/recordings/tenant1')
      expect(described_class.find(tenant.id).recording_dir).to eq '/mnt/recordings/tenant1'

      stored = described_class.find(tenant.id)
      stored.recording_dir = nil
      stored.save!

      expect(described_class.find(tenant.id).recording_dir).to be_nil
    end

    it 'reads a directory as an operator types it' do
      expect(described_class.parse_recording_dir('/mnt/recordings/tenant-1.a_b/')).to eq '/mnt/recordings/tenant-1.a_b'
      expect(described_class.parse_recording_dir('')).to be_nil
      expect(described_class.parse_recording_dir(nil)).to be_nil
    end

    ['relative/path', '/', '/mnt/../etc', '/mnt/./x', '/mnt/with space', '/mnt/a;b', "/mnt/a\n/b", '//mnt'].each do |dir|
      it "refuses #{dir.inspect}" do
        expect { described_class.parse_recording_dir(dir) }.to raise_error(ArgumentError, /absolute path/)
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
