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

  describe ':showall' do
    let(:task) { Rake::Task['tenants:showall'] }

    it 'lists all tenants' do
      tenant1 = create(:tenant)
      tenant2 = create(:tenant)

      expect { task.invoke }.to output(
                                  /TenantID, Name, Secrets\n#{tenant1.id}, #{tenant1.name}, #{tenant1.secrets}\n#{tenant2.id}, #{tenant2.name}, #{tenant2.secrets}\nTotal number of tenants: 2\n/
                                ).to_stdout
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
