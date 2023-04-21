# frozen_string_literal: true

# TODO - is this needed? can be put directly in spec configs?

module RSpec
  module RedisHelper
    # When this module is included into the rspec config,
    # it will set up an around(:each) block to clear redis.
    def self.included(rspec)
      rspec.after(:each, redis: true) do |_example|
        Redis.current.flushdb
      end
    end

    CONFIG = { url: ENV["REDIS_URL"] || "redis://127.0.0.1:6379/1" }

    def redis
      @redis ||= ::Redis.connect(CONFIG)
    end

    def with_clean_redis
      redis.flushall            # clean before run
      begin
        yield
      ensure
        redis.flushall          # clean up after run
      end
    end
  end
end
