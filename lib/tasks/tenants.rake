# frozen_string_literal: true

def check_multitenancy
  # abort 'Multitenancy is disabled, task can not be completed' unless ENV['MULTITENANCY_ENABLED']
end

def fetch_tenant(id)
  tenant = Tenant.find_by id: id
  if tenant.blank?
    puts("Tenant with id #{id} does not exist in the system. Exiting...")
    exit(1)
  end
end

namespace :tenants do
  desc 'List all the Tenants'
  task showall: :environment do |_t, _args|
    check_multitenancy
    tenants = Tenant.all

    if tenants.present?
      puts "TenantID, Name, Secrets"
      tenants.each do |tenant|
        puts "#{tenant.id}, #{tenant.name}, #{tenant.secrets}"
      end
    end

    puts "Total number of tenants: #{tenants.size}"
  end

  desc 'Add a new Tenant'
  task :add, [:name, :secrets] => :environment do |_t, args|
    check_multitenancy
    name = args[:name]
    secrets = args[:secrets]

    unless name.present? && secrets.present?
      puts('Error: both name and secrets are required to create a Tenant')
      exit(1)
    end

    tenant = Tenant.new(name: name, secrets: secrets)

    if tenant.valid?
      tenant.save!
      puts('OK')
      puts("New Tenant id: #{tenant.id}")
    else
      puts('Error! Tenant has not been created. Please fix the following errors:')
      puts(tenant.errors.messages.to_s)
      exit(1)
    end
  end

  desc 'Update existing Tenant'
  task :update, [:id, :name, :secrets] => :environment do |_t, args|
    check_multitenancy
    id = args[:id].to_i
    name = args[:name]
    secrets = args[:secrets]

    tenant = fetch_tenant(id)

    if tenant.update(name: name, secrets: secrets)
      puts("Tenant was updated successfully")
    else
      puts('Error! Tenant was not updated. Please fix the following errors:')
      puts(tenant.errors.messages.to_s)
      exit(1)
    end
  end

  desc 'Remove existing Tenant'
  task :remove, [:id] => :environment do |_t, args|
    check_multitenancy
    id = args[:id].to_i

    tenant = fetch_tenant(id)

    if tenant.delete
      puts("Tenant was successfully deleted.")
    else
      puts("Error! Tenant has not been deleted")
    end
  end

  namespace :params do
    desc 'List Custom Parameters for Tenant'
    task :showall, [:id] => :environment do |_t, args|
      check_multitenancy
      id = args[:id].to_i

      tenant = fetch_tenant(id)
      custom_settings = tenant.custom_settings

      puts "Tenant has #{custom_settings.size} custom settings"

      puts "Name - Value"

      custom_settings.each do |cs|
        puts "#{cs.name} - #{cs.value}"
      end
    end

    desc 'Add Custom Parameter for Tenant'
    task :set, [:tenant_id, :param_name, :param_value] => :environment do |_t, args|
      check_multitenancy
      id = args[:tenant_id].to_i
      param_name = args[:param_name]
      param_value = args[:param_value]

      tenant = fetch_tenant(id)

      custom_settings = tenant.custom_settings
      setting = custom_settings.find_or_create_by(name: param_name)
      setting.value = param_value

      setting.save!

      puts "Attribute #{setting.name} was successfully set to #{setting.value}."
    end

    desc 'Delete Custom Parameter for Tenant'
    task :remove, [:tenant_id, :param_name] => :environment do |_t, args|
      check_multitenancy
      id = args[:tenant_id].to_i
      param_name = args[:param_name]

      tenant = fetch_tenant(id)

      custom_setting = tenant.custom_settings.find_by(name: param_name)
      if custom_setting.present?
        custom_setting.destroy
        puts "Custom setting with name #{param_name} was successfully deleted"
      else
        puts "Custom setting with name #{param_name} was not found in the database."
      end
    end
  end
end
