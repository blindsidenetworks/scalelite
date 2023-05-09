# frozen_string_literal: true

def check_multitenancy
  abort 'Multitenancy is disabled, task can not be completed' unless ENV['MULTITENANCY_ENABLED']
end

desc 'List all the Tenants'
task tenants: :environment do |_t, _args|
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

namespace :tenants do
  desc 'Add a new Tenant'
  task :add, [:name, :secrets] => :environment do |_t, args|
    check_multitenancy
    name = args[:name]
    secrets = args[:secrets]

    unless name.present? && secrets.present?
      puts('Error: both name and secrets are required to create a Tenant')
      exit(1)
    end

    tenant = Tenant.create!(name: name, secrets: secrets)

    puts('OK')
    puts("New Tenant id: #{tenant.id}")
  end

  desc 'Remove existing Tenant'
  task :remove, [:id] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]

    tenant = Tenant.find(id)
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
