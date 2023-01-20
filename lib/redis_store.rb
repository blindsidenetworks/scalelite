# frozen_string_literal: true

module RedisStore
  @mutex = Mutex.new

  def self.connection_pool
    return @connection_pool if @connection_pool

    @mutex.synchronize do
      return @connection_pool if @connection_pool

      # Reading from ENV is probably fine here; only happens once near (but not at) application init,
      # and it's a fallback, and there's no way exposed in rails to read this value other than ENV.
      # rubocop:disable Rails/EnvironmentVariableAccess
      pool = Rails.configuration.x.redis_store.pool || ENV['RAILS_MAX_THREADS'] || ConnectionPool::DEFAULTS[:size]
      # rubocop:enable Rails/EnvironmentVariableAccess
      pool_timeout = Rails.configuration.x.redis_store.pool_timeout || ConnectionPool::DEFAULTS[:timeout]
      @connection_pool = ConnectionPool.new(size: pool, timeout: pool_timeout) do
        redis = Redis.new(Rails.configuration.x.redis_store)

        namespace = Rails.configuration.x.redis_store.namespace
        redis = Redis::Namespace.new(namespace, redis: redis) if namespace

        redis
      end
    end
  end

  def self.before_fork
    @mutex.synchronize do
      return if @connection_pool.nil?

      @connection_pool.shutdown
      @connection_pool = nil
    end
  end

  def self.with_connection(&block)
    connection_pool.with(&block)
  end
end
