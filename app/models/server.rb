# frozen_string_literal: true

class Server < ApplicationRedisRecord
  define_attribute_methods :id, :url, :secret, :enabled, :load, :online, :load_multiplier, :healthy_counter, :unhealthy_counter

  # Unique ID for this server
  application_redis_attr :id

  # Full URL used to make API requests to this server
  application_redis_attr :url

  # Shared secret for making API requests to this server
  application_redis_attr :secret

  # Whether the server is administratively enabled (allowed to create new meetings)
  application_redis_attr :enabled

  # Indicator of current server load
  application_redis_attr :load

  # Whether the server is considered online (checked when server polled)
  attr_reader :online

  # Counter for number of times a request succeeds for an offline server
  attr_reader :healthy_counter

  # Counter for number of times a request fails for an online server
  attr_reader :unhealthy_counter

  # Special load multiplier for this server to enable server-weight
  application_redis_attr :load_multiplier

  def online=(value)
    value = !!value
    online_will_change! unless @online == value
    @online = value
  end

  def save!
    with_connection do |redis|
      raise RecordNotSaved.new('Cannot update id field', self) if id_changed?

      # Default values
      self.id = SecureRandom.uuid if id.nil?
      self.online = false if online.nil?

      # Ignore load changes (would re-add to server_load set) unless enabled
      unless enabled
        self.load = nil
        clear_attribute_changes([:load])
      end

      server_key = key
      redis.multi do
        redis.hset(server_key, 'url', url) if url_changed?
        redis.hset(server_key, 'secret', secret) if secret_changed?
        redis.hset(server_key, 'online', online ? 'true' : 'false') if online_changed?
        redis.hset(server_key, 'load_multiplier', load_multiplier) if load_multiplier_changed?
        redis.sadd('servers', id) if id_changed?
        if enabled_changed?
          if enabled
            redis.sadd('server_enabled', id)
          else
            redis.srem('server_enabled', id)
            redis.zrem('server_load', id)
          end
        end
        if load_changed?
          if load.present?
            redis.zadd('server_load', load, id)
          else
            redis.zrem('server_load', id)
          end
        end
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
        redis.srem('servers', id)
        redis.zrem('server_load', id)
        redis.srem('server_enabled', id)
      end
    end

    # Superclass bookkeeping
    super
  end

  # Apply a concurrency-safe adjustment to the server load
  # Does nothing is the server is not available (enabled and online)
  def increment_load(amount)
    multiplier = load_multiplier.nil? ? 1.0 : load_multiplier
    with_connection do |redis|
      self.load = redis.zadd('server_load', amount * multiplier.to_d, id, xx: true, incr: true)
      clear_attribute_changes([:load])
      load
    end
  end

  # Apply a concurrency-safe increment to the healthy counter by 1
  def increment_healthy
    with_connection do |redis|
      redis.hincrby(id, 'healthy_counter', 1)
    end
  end

  # Apply a concurrency-safe increment to the healthy counter by 1
  def increment_unhealthy
    with_connection do |redis|
      redis.hincrby(id, 'unhealthy_counter', 1)
    end
  end

  # Resets both healthy and unhealthy counter to 0
  # Done once the server has changed from online to offline or vice versa
  def reset_counters
    with_connection do |redis|
      redis.hmset(id, 'healthy_counter', 0, 'unhealthy_counter', 0)
    end
  end

  # Find a server by ID
  def self.find(id)
    with_connection do |redis|
      hash, enabled, load = redis.pipelined do
        redis.hgetall(key(id))
        redis.sismember('server_enabled', id)
        redis.zscore('server_load', id)
      end
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if hash.blank?

      hash['id'] = id
      hash['enabled'] = enabled
      hash['load'] = load if enabled
      hash['online'] = (hash['online'] == 'true')
      new.init_with_attributes(hash)
    end
  end

  # Find the server with the lowest load (for creating a new meeting)
  def self.find_available
    with_connection do |redis|
      id, load, hash = 5.times do
        ids_loads = redis.zrange('server_load', 0, 0, with_scores: true)
        raise RecordNotFound.new("Couldn't find available Server", name, nil) if ids_loads.blank?

        id, load = ids_loads.first
        hash = redis.hgetall(key(id))
        break id, load, hash if hash.present?
      end
      raise RecordNotFound.new("Couldn't find available Server", name, id) if hash.blank?

      hash['id'] = id
      hash['enabled'] = true # all servers in server_load set are enabled
      hash['load'] = load
      hash['online'] = (hash['online'] == 'true')
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
        hash, enabled, load = redis.pipelined do
          redis.hgetall(key(id))
          redis.sismember('server_enabled', id)
          redis.zscore('server_load', id)
        end
        next if hash.blank?

        hash['id'] = id
        hash['enabled'] = enabled
        hash['load'] = load if enabled
        hash['online'] = (hash['online'] == 'true')
        servers << new.init_with_attributes(hash)
      end
    end
    servers
  end

  # Get a list of all available servers (enabled and online)
  def self.available
    servers = []
    with_connection do |redis|
      redis.zrange('server_load', 0, -1, with_scores: true).each do |id, load|
        hash = redis.hgetall(key(id))
        next if hash.blank?

        hash['id'] = id
        hash['enabled'] = true # all servers in server_load set are enabled
        hash['load'] = load
        hash['online'] = (hash['online'] == 'true')
        servers << new.init_with_attributes(hash)
      end
    end
    servers
  end

  # Get a list of all enabled servers
  def self.enabled
    servers = []
    with_connection do |redis|
      redis.smembers('server_enabled').each do |id|
        hash, load = redis.pipelined do
          redis.hgetall(key(id))
          redis.zscore('server_load', id)
        end

        hash['id'] = id
        hash['enabled'] = true
        hash['load'] = load
        hash['online'] = (hash['online'] == 'true')
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
