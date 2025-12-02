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

      [tenant1, tenant2].each do |tenant|
        expect(Rails.logger).to receive(:info).with("id: #{tenant.id}")
        expect(Rails.logger).to receive(:info).with("\tname: #{tenant.name}")
        expect(Rails.logger).to receive(:info).with("\tsecrets: #{tenant.secrets}")
      end
      expect(Rails.logger).to receive(:info).with('Total number of tenants: 2')

      task.invoke
    end

    it 'displays a message if there are no tenants' do
      expect(Rails.logger).to receive(:info).with('Total number of tenants: 0')

      task.invoke
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
