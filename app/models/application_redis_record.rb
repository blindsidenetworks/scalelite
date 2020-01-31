# frozen_string_literal: true

class ApplicationRedisRecord
  include ActiveModel::Model

  def connection_pool
    RedisConnectionManager.connection_pool
  end

  def with_connection
    RedisConnectionManager.with_connection
  end
end
