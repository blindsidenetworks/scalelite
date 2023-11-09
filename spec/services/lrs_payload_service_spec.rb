# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LrsPayloadService, type: :service do
  let!(:tenant) do
    create(:tenant,
           name: 'bn',
           lrs_endpoint: 'https://lrs_endpoint.com',
           kc_token_url: 'https://token_url.com/auth/token',
           kc_client_id: 'client_id',
           kc_client_secret: 'client_secret',
           kc_username: 'kc_username',
           kc_password: 'kc_password')
  end

  describe '#call' do
    it 'makes a call to kc_token_url with the correct payload' do
      payload = {
        client_id: tenant.kc_client_id,
        client_secret: tenant.kc_client_secret,
        username: tenant.kc_username,
        password: tenant.kc_password,
        grant_type: 'password'
      }

      stub_create = stub_request(:post, tenant.kc_token_url)
                    .with(body: payload).to_return(body: "kc_access_token")

      described_class.new(tenant: tenant, secret: 'server-secret').call

      expect(stub_create).to have_been_requested
    end

    it 'logs a warning and returns nil if kc_token_url returns an error' do
      stub_request(:post, tenant.kc_token_url)
        .to_return(status: 500, body: 'Internal Server Error', headers: {})

      expect(Rails.logger).to receive(:warn)

      expect(described_class.new(tenant: tenant, secret: 'server-secret').call).to be_nil
    end
  end
end
