# frozen_string_literal: true

class Meeting < ApplicationRedisRecord
  define_attribute_methods :id, :server_id

  # Meeting ID provided on create request
  application_redis_attr :id
  # ID of the server that the meeting was created on
  application_redis_attr :server_id

  def save!
    raise RecordNotSaved.new('Not implemented', self)
  end

  def destroy!
    raise RecordNotDestroyed.new('Not implemented', self)
  end

  def self.key(id)
    "meeting:#{id}"
  end

  # Find a meeting by ID
  def self.find(id)
    with_connection do |redis|
      meeting_hash = redis.hgetall(key(id))
      raise RecordNotFound.new("Couldn't find Meeting with id=#{id}", name, id) if meeting_hash.blank?

      meeting_hash[:id] = id
      new(meeting_hash)
    end
  end

  # Retrieve all meetings
  def self.all
    meetings = []
    with_connection do |redis|
      meeting_ids = redis.smembers('meetings')
      meeting_ids.each do |id|
        meeting_hash = redis.hgetall(key(id))
        next if meeting_hash.blank?

        meeting_hash[:id] = id
        meetings << new(meeting_hash)
      end
    end
    meetings
  end

  # "belongs to" Server
  def server
    return nil if server_id.nil?

    Server.find(server_id)
  end
end
