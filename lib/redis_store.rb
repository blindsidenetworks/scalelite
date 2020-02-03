# frozen_string_literal: true

module RedisStore
  @mutex = Mutex.new

  def self.connection_pool
    return @connection_pool if @connection_pool

    @mutex.synchronize do
      pool = ENV['REDIS_POOL'] || ENV['RAILS_MAX_THREADS'] || Rails.configuration.x.redis_store.pool || 5
      @connection_pool = ConnectionPool.new(size: pool) do
        opts = Rails.configuration.x.redis_store
        redis = Redis.new(opts)

        namespace = Rails.configuration.x.redis_store.namespace
        redis = Redis::Namespace.new(namespace, redis: redis) if namespace

        redis
      end
    end
  end

  def self.with_connection
    connection_pool.with { |connection| yield(connection) }
  end
end
