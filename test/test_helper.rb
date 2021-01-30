# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'fakeredis/minitest'
require 'webmock/minitest'
require 'minitest/stub_any_instance'

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Add more helper methods to be used by all tests here...

    def encode_bbb_params(api_method, query_string)
      checksum = ::Digest::SHA1.hexdigest("#{api_method}#{query_string}#{Rails.configuration.x.app_secret}")
      if query_string.blank?
        "checksum=#{checksum}"
      else
        "#{query_string}&checksum=#{checksum}"
      end
    end
  end
end
