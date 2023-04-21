# frozen_string_literal: true

module RSpec
  module RedisHelper
    # When this module is included into the rspec config,
    # it will set up an around(:each) block to clear redis.
    def self.included(rspec)
      rspec.around(:each, redis: true) do |spec|
        with_clean_redis do
          spec.run
        end
      end
    end

    def redis
      @redis ||= ::Redis.new(::Rails.application.config_for(:redis_store).symbolize_keys)
    end

    def with_clean_redis
      redis.flushdb # clean before run
      begin
        yield
      ensure
        redis.flushdb # clean up after run
      end
    end
  end
end
