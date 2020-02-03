# frozen_string_literal: true

class Server < ApplicationRedisRecord
  # Unique ID for this server
  attr_accessor :id
  # Full URL used to make API requests to this server
  attr_accessor :url
  # Shared secret for making API requests to this server
  attr_accessor :secret
  # Indicator of current server load
  attr_accessor :load

  def self.key(id)
    "server:#{id}"
  end

  # Find a server by ID
  def self.find(id)
    with_connection do |redis|
      server_hash = redis.hgetall(key(id))
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if server_hash.blank?

      server_hash[:id] = id
      server_hash[:load] = redis.zscore('server_load', id)
      new(server_hash)
    end
  end

  # Find the server with the lowest load (for creating a new meeting)
  def self.find_available
    with_connection do |redis|
      servers = redis.zrange('server_load', 0, 0, with_scores: true)
      raise RecordNotFound.new("Couldn't find available Server", name, nil) if servers.blank?

      id, score = servers[0]
      server_hash = redis.hgetall(key(id))
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if server_hash.blank?

      server_hash[:id] = id
      server_hash[:load] = score
      new(server_hash)
    end
  end
end
