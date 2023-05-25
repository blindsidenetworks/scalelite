# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::TenantsController, type: :controller do
  include ApiHelper

  describe 'GET #index' do
    context 'with multitenancy enabled' do
      before do
        Rails.configuration.x.multitenancy_enabled = true
      end

      it 'returns a list of all tenants' do
        tenants = create_list(:tenant, 3)
        get :index
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
        get :index
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['message']).to eq('No tenants exist')
      end
    end

    context 'with multitenancy disabled' do
      it 'returns nil if multitenancy is disabled' do
        Rails.configuration.x.multitenancy_enabled = false
        get :index
        expect(response).to have_http_status(:precondition_failed)
        expect(response.parsed_body['message']).to eq('Multitenancy is disabled')
      end
    end
  end

  describe 'GET #show' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    it 'returns the tenant associated with the given ID' do
      tenant = create(:tenant)
      get :show, params: { id: tenant.id }
      expect(response).to have_http_status(:ok)
      returned_tenant = response.parsed_body
      expect(returned_tenant['name']).to eq(tenant.name)
      expect(returned_tenant['secrets']).to eq(tenant.secrets)
    end

    it 'renders an error message if the tenant was not found' do
      get :show, params: { id: 'nonexistent-id' }
      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['error']).to eq("Couldn't find Tenant with id=nonexistent-id")
    end
  end

  describe 'POST #create' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    context 'with valid parameters' do
      let(:valid_params) {
        { name: 'test-tenant',
          secrets: 'test-secret' }
      }

      it 'creates a new tenant' do
        expect { post :create, params: { tenant: valid_params } }.to change { Tenant.all.count }.by(1)
        expect(response).to have_http_status(:created)
        response_data = response.parsed_body
        expect(response_data['id']).to be_present
      end
    end

    context 'with invalid parameters' do
      it 'renders an error message if name is missing' do
        post :create, params: { tenant: { secrets: 'test-secret' } }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to eq('Error: both name and secrets are required to create a Tenant')
      end

      it 'renders an error message if secret is missing' do
        post :create, params: { tenant: { name: 'test-name' } }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body['message']).to eq('Error: both name and secrets are required to create a Tenant')
      end
    end
  end

  describe 'PATCH #update' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    it 'updates a tenant name' do
      tenant = create(:tenant)
      new_tenant_params = { name: 'new-name' }
      patch :update, params: { id: tenant.id, tenant: new_tenant_params }
      expect(response).to have_http_status(:ok)
      expect(Tenant.find(tenant.id).name).to eq('new-name') # check that the id-> name index was updated
      expect(Tenant.find_by_name('new-name')).not_to be_nil # check that the new name->id index has been added
      expect(Tenant.find_by_name(tenant.name)).to be_nil # check that the old name->id index has been deleted
    end

    it 'updates a tenant secret' do
      tenant = create(:tenant)
      new_tenant_params = { secrets: 'new-secret' }
      patch :update, params: { id: tenant.id, tenant: new_tenant_params }
      expect(response).to have_http_status(:ok)
      expect(Tenant.find(tenant.id).secrets).to eq('new-secret') # check that the id-> secret index was updated
    end
  end

  describe 'DELETE #destroy' do
    before do
      Rails.configuration.x.multitenancy_enabled = true
    end

    context 'with an existing tenant' do
      it 'deletes the tenant' do
        tenant = create(:tenant)
        expect { delete :destroy, params: { id: tenant.id } }.to change { Tenant.all.count }.by(-1)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['id']).to eq(tenant.id)
      end
    end

    context 'with a non-existent tenant' do
      it 'does not delete any tenant' do
        delete :destroy, params: { id: 'nonexistent-id' }
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body['error']).to eq("Couldn't find Tenant with id=nonexistent-id")
      end
    end
  end
end
