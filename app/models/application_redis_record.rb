# frozen_string_literal: true

class ApplicationRedisRecord
  include ActiveModel::Model
  include ActiveModel::AttributeMethods

  class ApplicationRedisError < StandardError
  end

  class RecordNotFound < ApplicationRedisError
    attr_reader :model, :id

    def initialize(message = nil, model = nil, id = nil)
      @model = model
      @id = id

      super(message)
    end
  end

  def self.connection_pool
    RedisStore.connection_pool
  end

  def self.with_connection
    RedisStore.with_connection do |redis|
      yield redis
    end
  end
end
