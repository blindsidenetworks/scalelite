# frozen_string_literal: true

class Server < ApplicationRedisRecord
  define_attribute_methods :id, :url, :secret, :load

  # Unique ID for this server
  application_redis_attr :id

  # Full URL used to make API requests to this server
  application_redis_attr :url

  # Shared secret for making API requests to this server
  application_redis_attr :secret

  # Indicator of current server load
  application_redis_attr :load

  def save!
    with_connection do |redis|
      raise RecordNotSaved.new('Cannot update id field', self) if id_changed?

      # Default values
      self.id = SecureRandom.uuid if id.nil?

      server_key = key
      redis.multi do
        redis.hset(server_key, 'url', url) if url_changed?
        redis.hset(server_key, 'secret', secret) if secret_changed?
        if load_changed?
          if load.nil?
            redis.zrem('server_load', id)
          else
            redis.zadd('server_load', load, id)
          end
        end
        redis.sadd('servers', id) if id_changed?
      end
    end

    # Superclass bookkeeping
    super
  end

  def destroy!
    with_connection do |redis|
      raise RecordNotDestroyed.new('Object is not persisted', self) unless persisted?
      raise RecordNotDestroyed.new('Object has uncommitted changes', self) if changed?

      redis.multi do
        redis.del(key)
        redis.zrem('server_load', id)
        redis.srem('servers', id)
      end
    end

    # Superclass bookkeeping
    super
  end

  # Apply a concurrency-safe adjustment to the server load
  def increment_load(amount)
    with_connection do |redis|
      self.load = redis.zincrby('server_load', amount, id)
      clear_attribute_changes([:load])
    end
  end

  # Find a server by ID
  def self.find(id)
    with_connection do |redis|
      hash, load = redis.pipelined do
        redis.hgetall(key(id))
        redis.zscore('server_load', id)
      end
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if hash.blank?

      hash[:id] = id
      hash[:load] = load
      new.init_with_attributes(hash)
    end
  end

  # Find the server with the lowest load (for creating a new meeting)
  def self.find_available
    with_connection do |redis|
      ids_loads = redis.zrange('server_load', 0, 0, with_scores: true)
      raise RecordNotFound.new("Couldn't find available Server", name, nil) if ids_loads.blank?

      id, load = ids_loads.first
      hash = redis.hgetall(key(id))
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if hash.blank?

      hash[:id] = id
      hash[:load] = load
      new.init_with_attributes(hash)
    end
  end

  # Get a list of all servers
  def self.all
    servers = []
    with_connection do |redis|
      ids = redis.smembers('servers')
      return servers if ids.blank?

      ids.each do |id|
        hash, load = redis.pipelined do
          redis.hgetall(key(id))
          redis.zscore('server_load', id)
        end
        next if hash.blank?

        hash[:id] = id
        hash[:load] = load
        servers << new.init_with_attributes(hash)
      end
    end
    servers
  end

  # Get a list of all available servers
  def self.available
    servers = []
    with_connection do |redis|
      ids_loads = redis.zrange('server_load', 0, -1, with_scores: true)
      return servers if ids_loads.blank?

      ids_loads.each do |id, load|
        hash = redis.hgetall(key(id))
        next if hash.blank?

        hash[:id] = id
        hash[:load] = load
        servers << new.init_with_attributes(hash)
      end
    end
    servers
  end

  def self.key(id)
    "server:#{id}"
  end

  def key
    self.class.key(id)
  end
end
