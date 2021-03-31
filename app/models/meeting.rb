# frozen_string_literal: true

class Meeting < ApplicationRedisRecord
  define_attribute_methods :id, :server_id, :moderator_pw

  # Meeting ID and moderator_pw provided on create request
  application_redis_attr :id, :moderator_pw

  # ID of the server that the meeting was created on
  attr_reader :server_id

  def server_id=(value)
    server_id_will_change! unless @server_id == value
    @server_id = value
    return if @server.nil?

    @server = nil unless @server.id == value
  end

  # Implement a "belongs to" style relation to Server
  def server
    @server ||= \
      if server_id.nil?
        nil
      else
        Server.find(server_id)
      end
  end

  # Allow assigning a server object to update the linked server
  def server=(obj)
    if obj.nil?
      server_id_will_change! unless @server_id.nil?
      @server_id = @server = nil
    else
      server_id_will_change! unless @server_id == obj.id
      @server = obj
      @server_id = obj.id
    end
  end

  def save!
    raise RecordNotSaved.new('Cannot update id field', self) if id_changed? && !id_was.nil?
    raise RecordNotSaved.new('Meeting id must be set', self) if id.nil?

    with_connection do |redis|
      meeting_key = key
      redis.multi do
        redis.hset(meeting_key, 'server_id', server_id) if server_id_changed?
        redis.sadd('meetings', id) if id_changed?
      end
    end

    # Superclass bookkeeping
    super
  end

  def destroy!
    raise RecordNotDestroyed.new('Object is not persisted', self) unless persisted?
    raise RecordNotDestroyed.new('Object has uncommitted changes', self) if changed?

    with_connection do |redis|
      redis.multi do
        redis.del(key)
        redis.srem('meetings', id)
      end
    end

    # Superclass bookkeeping
    super
  end

  # Atomic operation to either find an existing meeting, or create one assigned to a specific server
  # Intended for use with the BigBlueButton "create" api command.
  def self.find_or_create_with_server(id, server, moderator_pw)
    raise ArgumentError, 'id is nil' if id.nil?
    raise ArgumentError, "Provided server doesn't have an id" if server.nil? || server.id.nil?

    with_connection do |redis|
      meeting_key = key(id)
      created, _password_set, hash, _sadd_id = redis.multi do
        redis.hsetnx(meeting_key, 'server_id', server.id)
        redis.hsetnx(meeting_key, 'moderator_pw', moderator_pw)
        redis.hgetall(meeting_key)
        redis.sadd('meetings', id)
      end

      logger.debug("Meeting find_or_create: created=#{created} on server_id=#{hash['server_id']} (wanted #{server.id})")

      hash[:id] = id
      hash[:server] = server if server.id == hash['server_id']
      new.init_with_attributes(hash)
    end
  end

  # Find a meeting by ID
  def self.find(id)
    with_connection do |redis|
      hash = redis.hgetall(key(id))
      raise RecordNotFound.new("Couldn't find Meeting with id=#{id}", name, id) if hash.blank?

      hash[:id] = id
      new.init_with_attributes(hash)
    end
  end

  # Retrieve all meetings
  def self.all
    meetings = []
    with_connection do |redis|
      ids = redis.smembers('meetings')
      ids.each do |id|
        hash = redis.hgetall(key(id))
        next if hash.blank?

        hash[:id] = id
        meetings << new.init_with_attributes(hash)
      end
    end
    meetings
  end

  def self.key(id)
    "meeting:#{id}"
  end

  def key
    self.class.key(id)
  end
end
