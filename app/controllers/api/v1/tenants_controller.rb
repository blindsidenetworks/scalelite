# frozen_string_literal: true

module Api
  module V1
    class TenantsController < ApplicationController
      skip_before_action :verify_authenticity_token

      before_action :check_multitenancy
      before_action :set_tenant, only: [:show, :update, :destroy]

      # Return a list of all tenants
      # GET /api/v1/tenants
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
      def index
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
      # GET /api/v1/tenants/:id
      #
      # Successful response:
      #  {
      #    "id": String,
      #    "name": String,
      #    "secrets": String,
      #    "new_record": Boolean,
      #    "destroyed": Boolean
      #  }
      def show
        render json: @tenant, status: :ok
      end

      # Add a new tenant
      # POST /api/v1/tenants
      #
      # Expected params:
      # {
      #   "name": String,                 # Required: Name of the tenant
      #   "secrets": String,              # Required: Tenant secret(s)
      # }
      def create
        if tenant_params[:name].blank? || tenant_params[:secrets].blank?
          render json: { message: 'Error: both name and secrets are required to create a Tenant' }, status: :bad_request
        else
          tenant = Tenant.create(tenant_params)
          render json: { id: tenant.id }, status: :created
        end
      end

      # Update a tenant
      # PUT api/v1/tenants/:id?name=xxx || PUT api/v1/tenants/:id?secrets=xxx
      #
      # Expected params:
      # {
      #   "name": String,     # include the parameter you want updated
      #   "secrets": String
      # }
      def update
        @tenant.name = tenant_params[:name] if tenant_params[:name].present?
        @tenant.secrets = tenant_params[:secrets] if tenant_params[:secrets].present?
        @tenant.save!
        render json: { tenant: @tenant.to_json }, status: :ok
      rescue ApplicationRedisRecord::RecordNotSaved => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      # Delete tenant
      # DELETE /api/v1/tenants/:id
      #
      # Successful response:
      # { "id" : String }
      def destroy
        @tenant.destroy!
        render json: { id: @tenant.id }, status: :ok
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
        return render json: { message: "Multitenancy is disabled" }, status: :precondition_failed unless Rails.configuration.x.multitenancy_enabled
      end
    end
  end
end
