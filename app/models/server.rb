# frozen_string_literal: true

class Server < ApplicationRedisRecord
  # Unique ID for this server
  attr_accessor :id
  # Full URL used to make API requests to this server
  attr_accessor :url
  # Shared secret for making API requests to this server
  attr_accessor :secret

  def self.key(id)
    "server:#{id}"
  end

  def self.find(id)
    h = with_connection do |redis|
      h = redis.hgetall(key(id))
      raise RecordNotFound.new("Couldn't find Server with id=#{id}", name, id) if h.empty?
    end
    new(h)
  end
end
