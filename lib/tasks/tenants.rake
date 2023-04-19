# frozen_string_literal: true

def check_multitenancy
  abort 'Multitenancy is disabled, task can not be completed' unless ENV['MULTITENANCY_ENABLED']
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
    byebug
    tenant = Tenant.create!(name: name, secrets: secrets)
    puts('OK')
    puts("New Tenant id: #{tenant.id}")
  end

  desc 'Update existing Tenant'
  task :update, [:id, :name, :secrets] => :environment do |_t, args|
    check_multitenancy
    id = args[:id].to_i
    name = args[:name]
    secrets = args[:secrets]

    tenant = Tenant.find_by id: id
    if tenant.blank?
      puts("Tenant with id #{id} does not exist in the system. Exiting...")
      exit(1)
    end

    if tenant.update(name: name, secrets: secrets)
      puts("Tenant was updated successfully")
    else
      puts('Error! Tenant was not updated. Please fix the following errors:')
      puts(tenant.errors.messages)
      exit(1)
    end
  end

  desc 'Remove existing Tenant'
  task :remove, [:id] => :environment do |_t, args|
    check_multitenancy
    id = args[:id].to_i

    tenant = Tenant.find_by id: id
    if tenant.blank?
      puts("Tenant with id #{id} does not exist in the system. Exiting...")
      exit(1)
    end

    if tenant.delete
      puts("Tenant was successfully deleted.")
    else
      puts("Error! Tenant has not been deleted")
    end
  end
end
