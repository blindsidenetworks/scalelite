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
    expect(verify_checksum).to eq true
  end
end

RSpec.describe ApiHelper, type: :helper do
  include ApiHelper

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

      context 'with SHA256' do
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

  describe '.get_checksum'

  describe 'encode_bbb_url'

  describe '.bbb_req timeout'

  describe '.encoded_token'

  describe '.decoded_token'

  describe '.post_req'

  describe 'get_post_req'

  describe 'add_additional_params'
end
