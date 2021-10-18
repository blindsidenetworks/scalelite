# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'fakeredis/minitest'
require 'webmock/minitest'
require 'minitest/stub_any_instance'
require 'minitest/mock'

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Add more helper methods to be used by all tests here...

    def encode_bbb_params(api_method, query_string)
      checksum = ::Digest::SHA1.hexdigest("#{api_method}#{query_string}#{Rails.configuration.x.loadbalancer_secrets[0]}")
      if query_string.blank?
        "checksum=#{checksum}"
      else
        "#{query_string}&checksum=#{checksum}"
      end
    end

    def reload_routes!
      Rails.application.reload_routes!
    end

    def mock_env(partial_env_hash)
      old = ENV.to_hash
      ENV.update(partial_env_hash)
      begin
        yield
      ensure
        ENV.replace(old)
        reload_routes!
      end
    end
  end
end
