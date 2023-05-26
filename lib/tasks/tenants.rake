# frozen_string_literal: true

def check_multitenancy
  abort 'Multitenancy is disabled, task can not be completed' unless ENV['MULTITENANCY_ENABLED']
end

desc 'List all the Tenants'
task tenants: :environment do |_t, _args|
  check_multitenancy
  tenants = Tenant.all

  if tenants.present?
    tenants.each do |tenant|
      puts("id: #{tenant.id}")
      puts("\tname: #{tenant.name}")
      puts("\tsecrets: #{tenant.secrets}")
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

  desc 'Update an existing Tenant'
  task :update, [:id, :name, :secrets] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]
    name = args[:name]
    secrets = args[:secrets]

    if id.blank? || !(name.present? || secrets.present?)
      puts('Error: id and either name or secrets are required to update a Tenant')
      exit(1)
    end

    tenant = Tenant.find(id)
    tenant.name = name if name.present?
    tenant.secrets = secrets if secrets.present?
    tenant.save!

    puts('OK')
    puts("Updated Tenant id: #{tenant.id}")
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

    if tenant.destroy!
      puts("Tenant was successfully deleted.")
    else
      puts("Error! Tenant has not been deleted")
    end
  end
end
