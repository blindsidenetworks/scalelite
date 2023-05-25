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

    puts "Tenant: #{tenant.name}"
    if settings.present?
      settings.each do |setting|
        puts("  id: #{setting.id}")
        puts("\tparam: #{setting.param}")
        puts("\tvalue: #{setting.value}")
        puts("\toverride: #{setting.override}")
      end
    else
      puts "  No custom settings are configured"
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
      puts('Error: tenant_id, param, value and override are required to create a TenantSetting')
      exit(1)
    end

    setting = TenantSetting.create!(tenant_id: tenant_id, param: param, value: value, override: override)

    puts('OK')
    puts("New TenantSetting id: #{setting.id}")
  end

  desc 'Remove existing TenantSetting'
  task :remove, [:id] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]

    setting = TenantSetting.find(id)
    if setting.blank?
      puts("TenantSetting with id #{id} does not exist in the system. Exiting...")
      exit(1)
    end

    if setting.destroy!
      puts("TenantSetting was successfully deleted.")
    else
      puts("Error! TenantSetting has not been deleted")
    end
  end
end
