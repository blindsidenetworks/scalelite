# frozen_string_literal: true

class Server < ApplicationRedisRecord
  define_attribute_methods :id, :url, :secret, :load

  # Unique ID for this server
  attr_reader :id

  def id=(value)
    id_will_change! unless @id == value
    @id = value
  end

  # Full URL used to make API requests to this server
  attr_reader :url

  def url=(value)
    url_will_change! unless @url == value
    @url = value
  end

  # Shared secret for making API requests to this server
  attr_reader :secret

  def secret=(value)
    secret_will_change! unless @secret == value
    @secret = value
  end

  # Indicator of current server load
  attr_reader :load

  def load=(value)
    load_will_change! unless @load == value
    @load = value
  end

  def save!
    with_connection do |redis|
      raise RecordNotSaved.new('Cannot update id field', self) if id_changed?

      # Default values
      id = SecureRandom.uuid if id.nil?
      load = Float::INFINITY if load.nil?

      server_key = key(id)
      redis.multi do
        redis.hset(server_key, 'url', url) if url_changed?
        redis.hset(server_key, 'secret', secret) if secret_changed?
        redis.zadd('server_load', id, load) if load_changed?
      end
    end

    # Superclass bookkeeping
    super
  end

  def destroy!
    with_connection do |redis|
      raise RecordNotDestroyed.new('Object is not persisted', self) unless persisted?
      raise RecordNotDestroyed.new('Object has uncommitted changes', self) if changed?

      server_key = key(id)
      redis.multi do
        redis.del(server_key)
        redis.zrem('server_load', id)
      end
    end

    # Superclass bookkeeping
    super
  end

  # Find a server by ID
  def self.find(id)
    with_connection do |redis|
      server_hash, server_load = redis.pipelined do
        redis.hgetall(key(id))
        redis.zscore('server_load', id)
      end
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if server_hash.blank?

      server_hash[:id] = id
      server_hash[:load] = server_load
      server = new
      server.init_with_attributes(server_hash)
      server
    end
  end

  # Find the server with the lowest load (for creating a new meeting)
  def self.find_available
    with_connection do |redis|
      servers = redis.zrange('server_load', 0, 0, with_scores: true)
      raise RecordNotFound.new("Couldn't find available Server", name, nil) if servers.blank?

      id, server_load = servers[0]
      server_hash = redis.hgetall(key(id))
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if server_hash.blank?

      server_hash[:id] = id
      server_hash[:load] = server_load
      server = new
      server.init_with_attributes(server_hash)
      server
    end
  end

  def self.key(id)
    "server:#{id}"
  end
end
