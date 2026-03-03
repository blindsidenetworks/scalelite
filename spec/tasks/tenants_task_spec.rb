# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'tenants tasks', type: :task do
  before do
    stub_const('ENV', ENV.to_h.merge('MULTITENANCY_ENABLED' => 'true'))
    Rails.application.load_tasks
  end

  after do
    Rake::Task.clear
  end

  describe ':tenants' do
    let(:task) { Rake::Task['tenants'] }

    it 'lists all tenants' do
      tenant1 = create(:tenant)
      tenant2 = create(:tenant)

      # rubocop:disable Layout/LineLength
      expect { task.invoke }.to output(
        "id: #{tenant2.id}\n\tname: #{tenant2.name}\n\tsecrets: #{tenant2.secrets}\nid: #{tenant1.id}\n\tname: #{tenant1.name}\n\tsecrets: #{tenant1.secrets}\nTotal number of tenants: 2\n"
      ).to_stdout
      # rubocop:enable Layout/LineLength
    end

    it 'displays a message if there are no tenants' do
      expect { task.invoke }.to output(/Total number of tenants: 0\n/).to_stdout
    end
  end

  describe ':add' do
    let(:task) { Rake::Task['tenants:add'] }

    it 'adds a new tenant' do
      tenant_name = 'tenant_name'
      tenant_secrets = 'tenant_secrets'
      expect {
        task.invoke(tenant_name, tenant_secrets)
      }.to change { Tenant.all.count }.by(1)
    end
  end

  describe ':update' do
    let(:task) { Rake::Task['tenants:update'] }
    let(:tenant) { create(:tenant) }

    it 'updates an existing tenant' do
      tenant_name = 'new_tenant_name'
      tenant_secrets = 'new_tenant_secrets'

      task.invoke(tenant.id, tenant_name, tenant_secrets)

      reload_tenant = Tenant.find(tenant.id)

      expect(reload_tenant.name).to eq(tenant_name)
      expect(reload_tenant.secrets).to eq(tenant_secrets)
    end
  end

  describe ':remove' do
    let(:task) { Rake::Task['tenants:remove'] }

    it 'removes an existing tenant' do
      tenant = create(:tenant)
      expect {
        task.invoke(tenant.id)
      }.to change { Tenant.all.count }.by(-1)
    end
  end
end
