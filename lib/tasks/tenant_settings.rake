# frozen_string_literal: true

def check_multitenancy
  abort 'Multitenancy is disabled, task can not be completed' unless ENV['MULTITENANCY_ENABLED']
end

desc 'List all the TenantSettings for a given tenant'
task tenantSettings: :environment do
  check_multitenancy

  tenants = Tenant.all

  tenants.each do |tenant|
    settings = TenantSetting.all(tenant.id)

    Rails.logger.info("Tenant: #{tenant.name}")
    if settings.present?
      settings.each do |setting|
        Rails.logger.info("  id: #{setting.id}")
        Rails.logger.info("\tparam: #{setting.param}")
        Rails.logger.info("\tvalue: #{setting.value}")
        Rails.logger.info("\toverride: #{setting.override}")
      end
    else
      Rails.logger.info('  No custom settings are configured')
    end
  end
end

namespace :tenantSettings do
  desc 'Add a new TenantSetting'
  task :add, [:tenant_id, :param, :value, :override] => :environment do |_t, args|
    check_multitenancy
    tenant_id = args[:tenant_id]
    param = args[:param]
    value = args[:value]
    override = args[:override]

    unless tenant_id.present? && param.present? && value.present? && override.present?
      Rails.logger.error('Error: tenant_id, param, value and override are required to create a TenantSetting')
      exit(1)
    end

    setting = TenantSetting.create!(tenant_id: tenant_id, param: param, value: value, override: override)

    Rails.logger.info('OK')
    Rails.logger.info("New TenantSetting id: #{setting.id}")
  end

  desc 'Remove existing TenantSetting'
  task :remove, [:id] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]

    setting = TenantSetting.find(id)
    if setting.blank?
      Rails.logger.error("TenantSetting with id #{id} does not exist in the system. Exiting...")
      exit(1)
    end

    if setting.destroy!
      Rails.logger.info('TenantSetting was successfully deleted.')
    else
      Rails.logger.error('Error! TenantSetting has not been deleted')
    end
  end
end
