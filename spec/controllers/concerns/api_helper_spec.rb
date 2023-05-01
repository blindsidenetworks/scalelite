# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'proper verify_checksum behavior' do |_parameter|
  it 'does not work without secret' do
    Rails.configuration.x.loadbalancer_secrets = []
    expect {
      verify_checksum
    }.to raise_error(BBBErrors::ChecksumError)
  end

  it 'verifies checksum' do
    expect(verify_checksum).to be true
  end
end

RSpec.describe ApiHelper, type: :helper do
  include described_class

  let(:request) { controller.request }

  describe 'checksum length' do
    context 'with correct length' do
      context 'with sha1' do
        let(:sha1) { Faker::Crypto.sha1 }

        it 'has correct length' do
          expect(ApiHelper::CHECKSUM_LENGTH_SHA1).to eq sha1.length
        end
      end

      context 'with sha256' do
        let(:sha256) { Faker::Crypto.sha256 }

        it 'has correct length' do
          expect(ApiHelper::CHECKSUM_LENGTH_SHA256).to eq sha256.length
        end
      end

      context 'with sha512' do
        let(:sha512) { Faker::Crypto.sha512 }

        it 'has correct length' do
          expect(ApiHelper::CHECKSUM_LENGTH_SHA512).to eq sha512.length
        end
      end
    end
  end

  describe '.verify_checksum' do
    let(:query_string) { 'querystring' }
    let(:action_name) { 'index' }
    let(:check_string) { action_name + query_string }
    let(:checksum_algo) { nil } # To be defined down the scope
    let(:secret) { 'IAmSecret' }
    let(:hash) { get_checksum(check_string + secret, checksum_algo) }

    before do
      controller.action_name = action_name
      allow(request).to receive(:query_string).and_return(query_string)
      Rails.configuration.x.loadbalancer_secrets = [secret]
    end

    context 'without params[:checksum]' do
      it 'throws an error' do
        expect {
          verify_checksum
        }.to raise_error(BBBErrors::ChecksumError)
      end
    end

    context 'with params' do
      context 'with SHA1' do
        let(:checksum_algo) { 'SHA1' }

        before do
          params[:checksum] = hash
        end

        include_examples 'proper verify_checksum behavior'
      end

      context 'with SHA256' do
        let(:checksum_algo) { 'SHA256' }

        before do
          params[:checksum] = hash
        end

        include_examples 'proper verify_checksum behavior'
      end

      context 'with SHA512' do
        let(:checksum_algo) { 'SHA512' }

        before do
          params[:checksum] = hash
        end

        include_examples 'proper verify_checksum behavior'
      end

      context 'with incorrect checksum' do
        let(:checksum_algo) { 'MD5' }

        before do
          params[:checksum] = 'totallyNotAHash'
        end

        it 'throws an error' do
          expect {
            verify_checksum
          }.to raise_error(BBBErrors::ChecksumError)
        end
      end
    end
  end

  describe '.fetch_tenant_name_from_url' do
    let(:host_name) { 'api.rna1.blindside-dev.com' }

    before do
      Rails.configuration.x.base_url = host_name
    end

    context 'with tenant name present' do
      before do
        controller.request.host = host
      end

      let(:subdomain) { 'carleton' }
      let(:host) { "#{subdomain}.#{host_name}" }

      it 'returns tenant name' do
        expect(fetch_tenant_name_from_url).to eq subdomain
      end
    end

    context 'with tenant name absent' do
      before do
        controller.request.host = host_name
      end

      it 'returns empty string' do
        expect(fetch_tenant_name_from_url).to eq ''
      end
    end
  end

  describe '.fetch_tenant' do
    let(:host_name) { 'api.rna1.blindside-dev.com' }
    let!(:tenant) { create(:tenant) }

    before do
      Rails.configuration.x.base_url = host_name
    end

    context 'with multitenancy enabled' do
      before do
        controller.request.host = host
        Rails.configuration.x.multitenancy_enabled = true
      end

      context 'with tenant in subdomain' do
        let(:subdomain) { tenant.name }
        let(:host) { "#{subdomain}.#{host_name}" }

        it 'properly sets tenant' do
          expect(fetch_tenant).to eq tenant
        end
      end

      context 'without tenant in subdomain' do
        let(:host) { host_name }

        it 'returns nil' do
          expect(fetch_tenant).to be_nil
        end
      end
    end

    context 'with multitenancy disabled' do
      before do
        controller.request.host = host
        Rails.configuration.x.multitenancy_enabled = false
      end

      context 'with tenant in subdomain' do
        let(:subdomain) { tenant.name }
        let(:host) { "#{subdomain}.#{host_name}" }

        it 'returns nil' do
          expect(fetch_tenant).to be_nil
        end
      end
    end
  end

  describe '.get_checksum'

  describe '.fetch_secrets' do
    let!(:tenant) { create(:tenant) }
    let(:config_secrets) { [Faker::Crypto.sha512, Faker::Crypto.sha256] }

    let(:host_name) { 'api.rna1.blindside-dev.com' }
    let(:subdomain) { tenant.name }

    before do
      Rails.configuration.x.loadbalancer_secrets = config_secrets
      Rails.configuration.x.base_url = host_name
      controller.request.host = host
    end

    context 'with multitenancy enabled' do
      before do
        Rails.configuration.x.multitenancy_enabled = true
      end

      context 'with tenant provided' do
        let(:host) { "#{subdomain}.#{host_name}" }

        it 'returns secrets from Tenant' do
          expect(fetch_secrets).to eq tenant.secrets_array
        end
      end

      context 'without tenant provided' do
        let(:host) { host_name }

        it 'returns secrets from config' do
          expect(fetch_secrets).to eq config_secrets
        end
      end
    end

    context 'with multitenancy disabled' do
      before do
        Rails.configuration.x.multitenancy_enabled = false
      end

      context 'without tenant provided' do
        let(:host) { host_name }

        it 'returns secrets from config' do
          expect(fetch_secrets).to eq config_secrets
        end
      end

      context 'with tenant provided' do
        let(:host) { "#{subdomain}.#{host_name}" }

        it 'returns secrets from config' do
          expect(fetch_secrets).to eq config_secrets
        end

        it 'does not return secrets from Tenant' do
          expect(fetch_secrets).not_to eq tenant.secrets_array
        end
      end
    end
  end

  describe 'encode_bbb_url'

  describe '.bbb_req timeout'

  describe '.encoded_token'

  describe '.decoded_token'

  describe '.post_req'

  describe 'get_post_req'

  describe 'add_additional_params'
end
