# frozen_string_literal: true

module Api
  class TenantsController < ScaleliteApiController
    before_action :check_multitenancy
    before_action :set_tenant, only: [:get_tenant_info, :update_tenant, :delete_tenant]

    # Return a list of all tenants
    # GET scalelite/api/getTenants
    #
    # Successful response:
    # [
    #   {
    #     "id": String,
    #     "name": String,
    #     "secrets": String,
    #   },
    #   ...
    # ]
    def get_tenants
      tenants = Tenant.all

      if tenants.empty?
        render json: { message: 'No tenants exist' }, status: :ok
      else
        tenants_list = tenants.map do |tenant|
          {
            id: tenant.id,
            name: tenant.name,
            secrets: tenant.secrets
          }
        end

        render json: tenants_list, status: :ok
      end
    end

    # Retrieve the information for a specific tenant
    # GET scalelite/api/getTenantInfo?id=
    #
    # Required Parameters:
    # { "id": String }
    #
    # Successful response:
    #  {
    #    "id": String,
    #    "name": String,
    #    "secrets": String,
    #  },
    #  ...
    def get_tenant_info
      render json: @tenant, status: :ok
    end

    # Add a new tenant
    # POST scalelite/api/addTenant
    #
    # Expected params:
    # {
    #   "tenant": {
    #     "name": String,                 # Required: Name of the tenant
    #     "secrets": String,              # Required: Tenant secret(s)
    #   }
    # }
    def add_tenant
      if tenant_params[:name].blank? || tenant_params[:secrets].blank?
        render json: { message: 'Error: both name and secrets are required to create a Tenant' }, status: :bad_request
      else
        tenant = Tenant.create(tenant_params)
        render json: { tenant: tenant }, status: :created
      end
    end

    # Update a tenant
    # POST scalelite/api/updateTenant
    #
    # Expected params:
    # {
    #   "id": String        # Required
    #   "tenant": {
    #     "name": String,     # include the parameter you want updated
    #     "secrets": String
    #   }
    # }
    def update_tenant
      @tenant.name = tenant_params[:name] if tenant_params[:name].present?
      @tenant.secrets = tenant_params[:secrets] if tenant_params[:secrets].present?
      @tenant.save!
      render json: { tenant: @tenant }, status: :ok
    rescue ApplicationRedisRecord::RecordNotSaved => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # Delete tenant
    # POST scalelite/api/deleteTenant
    #
    # Successful response:
    # { "id" : String }
    def delete_tenant
      @tenant.destroy!
      render json: { success: "Tenant id=#{@tenant.id} was destroyed" }, status: :ok
    rescue ApplicationRedisRecord::RecordNotDestroyed => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    private

    def set_tenant
      @tenant = Tenant.find(params[:id])
    rescue ApplicationRedisRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    end

    def tenant_params
      params.require(:tenant).permit(:name, :secrets)
    end

    def check_multitenancy
      render json: { message: "Multitenancy is disabled" }, status: :precondition_failed unless Rails.configuration.x.multitenancy_enabled
    end
  end
end
