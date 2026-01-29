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
      puts("\tlrs_endpoint: #{tenant.lrs_endpoint}") if tenant.lrs_endpoint.present?
      puts("\tlrs_username: #{tenant.lrs_username}") if tenant.lrs_username.present?
      puts("\tlrs_password: #{tenant.lrs_password}") if tenant.lrs_password.present?
      puts("\tkc_token_url: #{tenant.kc_token_url}") if tenant.kc_token_url.present?
      puts("\tkc_client_id: #{tenant.kc_client_id}") if tenant.kc_client_id.present?
      puts("\tkc_client_secret: #{tenant.kc_client_secret}") if tenant.kc_client_secret.present?
      puts("\tkc_username: #{tenant.kc_username}") if tenant.kc_username.present?
      puts("\tkc_password: #{tenant.kc_password}") if tenant.kc_password.present?
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
      warn('Error: both name and secrets are required to create a Tenant')
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
      warn('Error: id and either name or secrets are required to update a Tenant')
      exit(1)
    end

    tenant = Tenant.find(id)
    tenant.name = name if name.present?
    tenant.secrets = secrets if secrets.present?

    tenant.save!

    puts('OK')
    puts("Updated Tenant id: #{tenant.id}")
  end

  desc 'Update an existing Tenants LRS credentials with basic authentication'
  task :update_lrs_basic, [:id, :lrs_endpoint, :lrs_username, :lrs_password] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]
    lrs_endpoint = args[:lrs_endpoint]
    lrs_username = args[:lrs_username]
    lrs_password = args[:lrs_password]

    if id.blank? || lrs_endpoint.blank? || lrs_username.blank? || lrs_password.blank?
      warn('Error: id, LRS_ENDPOINT, LRS_USERNAME, LRS_PASSWORD are required to update a Tenant')
      exit(1)
    end

    tenant = Tenant.find(id)
    tenant.lrs_endpoint = lrs_endpoint
    tenant.lrs_username = lrs_username
    tenant.lrs_password = lrs_password

    tenant.save!

    puts('OK')
    puts("Updated Tenant id: #{tenant.id}")
  end

  desc 'Update an existing Tenants LRS credentials with Keycloak'
  task :update_lrs_kc, [:id, :lrs_endpoint, :kc_token_url, :kc_client_id, :kc_client_secret, :kc_username, :kc_password] => :environment do |_t, args|
    check_multitenancy
    id = args[:id]
    lrs_endpoint = args[:lrs_endpoint]
    kc_token_url = args[:kc_token_url]
    kc_client_id = args[:kc_client_id]
    kc_client_secret = args[:kc_client_secret]
    kc_username = args[:kc_username]
    kc_password = args[:kc_password]

    if id.blank? || lrs_endpoint.blank? || kc_token_url.blank? || kc_client_id.blank? ||
       kc_client_secret.blank? || kc_username.blank? || kc_password.blank?
      warn('Error: LRS_ENDPOINT, KC_TOKEN_URL, KC_CLIENT_ID, KC_CLIENT_SECRET, KC_USERNAME, KC_PASSWORD are required to update a Tenant')
      exit(1)
    end

    tenant = Tenant.find(id)
    tenant.lrs_endpoint = lrs_endpoint
    tenant.kc_token_url = kc_token_url
    tenant.kc_client_id = kc_client_id
    tenant.kc_client_secret = kc_client_secret
    tenant.kc_username = kc_username
    tenant.kc_password = kc_password

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
      warn("Tenant with id #{id} does not exist in the system. Exiting...")
      exit(1)
    end

    if tenant.destroy!
      # Should there be a puts("OK") here?
      puts('Tenant was successfully deleted.')
    else
      warn('Error! Tenant has not been deleted')
      # Should there be an exit(1) here?
    end
  end
end
