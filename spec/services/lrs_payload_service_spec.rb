# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LrsPayloadService, type: :service do
  describe '#call' do
    context 'Basic Auth' do
      it 'uses the lrs_basic_token if set' do
        tenant = create(:tenant, name: 'bn', lrs_endpoint: 'https://lrs_endpoint.com', lrs_basic_token: 'basic_token')

        encrypted_value = described_class.new(tenant: tenant, secret: 'server-secret').call

        expect(JSON.parse(decrypt(encrypted_value, 'server-secret'))["lrs_token"]).to eq(tenant.lrs_basic_token)
      end

      it 'logs a warning and returns nil if lrs_basic_token is not set' do
        tenant = create(:tenant, name: 'bn', lrs_endpoint: 'https://lrs_endpoint.com')

        expect(Rails.logger).to receive(:warn)

        expect(described_class.new(tenant: tenant, secret: 'server-secret').call).to be_nil
      end
    end

    context 'Keycloak' do
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

        expect(Rails.logger).to receive(:warn).twice

        expect(described_class.new(tenant: tenant, secret: 'server-secret').call).to be_nil
      end
    end
  end

  private

  def decrypt(encrypted_text, secret)
    decoded_text = Base64.strict_decode64(encrypted_text)

    salt = decoded_text[8, 8]
    ciphertext = decoded_text[16..]

    key_iv_bytes = OpenSSL::PKCS5.pbkdf2_hmac(secret, salt, 10000, 48, 'sha256')
    key = key_iv_bytes[0, 32]
    iv = key_iv_bytes[32..]

    decipher = OpenSSL::Cipher.new('aes-256-cbc')
    decipher.decrypt
    decipher.key = key
    decipher.iv = iv

    decipher.update(ciphertext) + decipher.final
  end

end

