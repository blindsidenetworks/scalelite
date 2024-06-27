# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::TenantsController do
  include ApiHelper

  before do
    # Disabling the checksum for the specs and re-enable it only when testing specifically the checksum
    allow_any_instance_of(described_class).to receive(:verify_checksum).and_return(true)
  end

  describe 'GET #tenants' do
    context 'with multitenancy enabled' do
      before do
        Rails.configuration.x.multitenancy_enabled = true
      end

      it 'returns a list of all tenants' do
        tenants = create_list(:tenant, 3)
        get scalelite_api_get_tenants_url
        expect(response).to have_http_status(:ok)
        tenants_list = response.parsed_body
        expect(tenants_list.size).to eq(3)

        tenants_list.each do |tenant_data|
          tenant = tenants.find { |t| t.id == tenant_data['id'] }
          expect(tenant).not_to be_nil
          expect(tenant_data['name']).to eq(tenant.name)
          expect(tenant_data['secrets']).to eq(tenant.secrets)
        end
      end

      it 'returns a message if there are no tenants' do
        get scalelite_api_get_tenants_url
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('No tenants exist')
      end
    end

    context 'with multitenancy disabled' do
      it 'returns nil if multitenancy is disabled' do
        Rails.configuration.x.multitenancy_enabled = false
        get scalelite_api_get_tenants_url
        expect(response).to have_http_status(:precondition_failed)
        expect(response.parsed_body['message']).to eq('Multitenancy is disabled')
      end
    end
  end

  describe 'GET #get_tenant_info' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    it 'returns the tenant associated with the given ID' do
      tenant = create(:tenant)
      get scalelite_api_get_tenant_info_url, params: { id: tenant.id }
      expect(response).to have_http_status(:ok)
      puts("response: #{response.parsed_body}")
      returned_tenant = response.parsed_body
      expect(returned_tenant['name']).to eq(tenant.name)
      expect(returned_tenant['secrets']).to eq(tenant.secrets)
    end

    it 'renders an error message if the tenant was not found' do
      get scalelite_api_get_tenant_info_url, params: { id: 'nonexistent-id' }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq("Couldn't find Tenant with id=nonexistent-id")
    end
  end

  describe 'POST #add_tenant' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    context 'with valid parameters' do
      let(:valid_params) {
        { name: 'test-tenant',
          secrets: 'test-secret' }
      }

      it 'creates a new tenant' do
        expect { post scalelite_api_add_tenant_url, params: { tenant: valid_params }, as: :json }.to change { Tenant.all.count }.by(1)
        expect(response).to have_http_status(:created)
        response_data = response.parsed_body
        expect(response_data['tenant']['id']).to be_present
      end
    end

    context 'with invalid parameters' do
      it 'renders an error message if name is missing' do
        post scalelite_api_add_tenant_url, params: { tenant: { secrets: 'test-secret' } }, as: :json
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to eq('Error: both name and secrets are required to create a Tenant')
      end

      it 'renders an error message if secret is missing' do
        post scalelite_api_add_tenant_url, params: { tenant: { name: 'test-name' } }, as: :json
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to eq('Error: both name and secrets are required to create a Tenant')
      end
    end
  end

  describe 'POST #update_tenant' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    it 'updates a tenant name' do
      tenant = create(:tenant)
      new_tenant_params = { name: 'new-name' }
      post scalelite_api_update_tenant_url, params: { id: tenant.id, tenant: new_tenant_params }, as: :json
      expect(response).to have_http_status(:ok)
      expect(Tenant.find(tenant.id).name).to eq('new-name') # check that the id-> name index was updated
      expect(Tenant.find_by_name('new-name')).not_to be_nil # check that the new name->id index has been added
      expect(Tenant.find_by_name(tenant.name)).to be_nil # check that the old name->id index has been deleted
    end

    it 'updates a tenant secret' do
      tenant = create(:tenant)
      new_tenant_params = { secrets: 'new-secret' }
      post scalelite_api_update_tenant_url, params: { id: tenant.id, tenant: new_tenant_params }, as: :json
      expect(response).to have_http_status(:ok)
      expect(Tenant.find(tenant.id).secrets).to eq('new-secret') # check that the id-> secret index was updated
    end
  end

  describe 'POST #delete_tenant' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    context 'with an existing tenant' do
      it 'deletes the tenant' do
        tenant = create(:tenant)
        expect { post scalelite_api_delete_tenant_url, params: { id: tenant.id }, as: :json }.to change { Tenant.all.count }.by(-1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['success']).to eq("Tenant id=#{tenant.id} was destroyed")
      end
    end

    context 'with a non-existent tenant' do
      it 'does not delete any tenant' do
        post scalelite_api_delete_tenant_url, params: { id: 'nonexistent-id' }, as: :json
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq("Couldn't find Tenant with id=nonexistent-id")
      end
    end
  end

  describe 'verify_checksum' do
    before do
      allow_any_instance_of(described_class).to receive(:verify_checksum).and_call_original
    end

    it 'successfully creates a tenant with checksum value computed using SHA1' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha1-secret'])
      url = URI(scalelite_api_add_tenant_url)
      url.query = "checksum=#{Digest::SHA1.hexdigest('addTenantsha1-secret')}"
      check_params = { tenant: { name: "SHA1-tenant", secrets: "SHA1-secret" } }
      post(url.to_s, params: check_params, as: :json)
      expect(response).to have_http_status(:created)
    end

    it 'successfully creates a tenant with checksum value computed using SHA256' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha256-secret'])
      url = URI(scalelite_api_add_tenant_url)
      url.query = "checksum=#{Digest::SHA1.hexdigest('addTenantsha256-secret')}"
      check_params = { tenant: { name: "SHA1-tenant", secrets: "SHA256-secret" } }
      post(url.to_s, params: check_params, as: :json)
      expect(response).to have_http_status(:created)
    end

    it 'returns a checksum error if the wrong secret is used' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha1-secret'])

      url = URI(scalelite_api_add_tenant_url)
      url.query = "checksum=#{Digest::SHA1.hexdigest('addTenantsha1-secret-incorrect')}"
      check_params = { tenant: { name: "SHA1-tenant", secrets: "SHA1-secret" } }
      post(url.to_s, params: check_params, as: :json)

      xml_response = Nokogiri::XML(response.body)
      expect(xml_response.at_xpath("//response/returncode").text).to eq("FAILED")
      expect(xml_response.at_xpath("//response/messageKey").text).to eq("checksumError")
    end

    it 'returns an error if the wrong content type is used' do
      allow(Rails.configuration.x).to receive(:loadbalancer_secrets).and_return(['sha1-secret'])

      url = URI(scalelite_api_add_tenant_url)
      url.query = "checksum=#{Digest::SHA1.hexdigest('addServersha1-secret')}"
      check_params = { tenant: { name: "SHA1-tenant", secrets: "SHA1-secret" } }
      post(url.to_s, params: check_params, as: :url_encoded_form)

      xml_response = Nokogiri::XML(response.body)
      expect(xml_response.at_xpath('/response/returncode').content).to eq('FAILED')
      expect(xml_response.at_xpath('/response/messageKey').content).to eq('unsupportedContentType')
    end
  end
end
