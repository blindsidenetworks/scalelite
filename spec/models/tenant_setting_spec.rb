# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TenantSetting, redis: true do
  let(:tenant) { create(:tenant) }

  describe '.find' do
    context 'with non-existent id' do
      it 'raises error' do
        expect {
          described_class.find('non-existent-id')
        }.to raise_error(ApplicationRedisRecord::RecordNotFound)
      end
    end

    context 'with correct id' do
      let(:setting) { create(:tenant_setting, tenant_id: create(:tenant).id) }

      it 'has proper settings' do
        set = described_class.find(setting.id)
        expect(set.id).to eq setting.id
        expect(set.param).to eq setting.param
        expect(set.value).to eq setting.value
        expect(set.override).to eq setting.override
        expect(set.tenant_id).to eq setting.tenant_id
      end
    end
  end

  describe '.all' do
    let!(:settings) { create_list(:tenant_setting, 5, tenant_id: tenant.id) }

    it 'returns all of the tenants' do
      all = described_class.all(tenant.id)
      expect(all.count).to eq(settings.count)
      expect(all.map(&:id)).to match_array(settings.map(&:id))
    end
  end

  describe '.defaults_and_overrides' do
    it 'correctly separates the ones with override true and false' do
      tenant = create(:tenant)
      defaults = create_list(:tenant_setting, 3, override: 'false', tenant_id: tenant.id)
      overrides = create_list(:tenant_setting, 3, override: 'true', tenant_id: tenant.id)

      default, override = described_class.defaults_and_overrides(tenant.id)
      expect(defaults.map(&:param)).to match_array(default.keys.map(&:to_s))
      expect(overrides.map(&:param)).to match_array(override.keys.map(&:to_s))
    end

    it 'returns empty hashes if the tenant is nil' do
      default, override = described_class.defaults_and_overrides(nil)
      expect(default).to eq({})
      expect(override).to eq({})
    end
  end
end
