# frozen_string_literal: true

class Meeting < ApplicationRedisRecord
  define_attribute_methods :id, :server_id, :moderator_pw, :tenant_id, :voice_bridge

  # @!attribute [rw]
  # The +meetingID+ parameter from the BigBlueButton create call.
  # @return [String] the Meeting's id
  application_redis_attr :id

  # @!attribute [rw]
  # The +moderatorPW+ parameter from the BigBlueButton create call.
  #
  # This parameter is stored because it's needed to perform some meeting specific API calls on older BigBlueButton versions.
  # @return [String] the token for indicating moderator priviledges.
  application_redis_attr :moderator_pw

  # The voice bridge number for the meeting, either provided on the BigBlueButton create request or allocated dynamically.
  # @return [String] the voice bridge num=begin  =endber.
  attr_reader :voice_bridge

  # ID of the Tenant this Meeting belongs to. Defaults to nil
  # @return [Integer] ID of the tenant.
  attr_accessor :tenant_id

  def voice_bridge=(value)
    raise ArgumentError, "Voice bridge cannot be updated once set" unless @voice_bridge.nil?

    voice_bridge_will_change! unless @voice_bridge == value
    @voice_bridge = value
  end

  # ID of the server that the meeting was created on.
  # @return [String] the server ID, which might be a UUID or normalized hostname depending on configuration.
  attr_reader :server_id

  def server_id=(value)
    server_id_will_change! unless @server_id == value
    @server_id = value
    return if @server.nil?

    @server = nil unless @server.id == value
  end

  # Update the linked tenant.
  # @param [Tenant] obj
  # @return [Tenant]
  def tenant=(obj)
    if obj.nil?
      @tenant_id = @tenant = nil
    else
      @tenant = obj
      @tenant_id = obj.id
    end
  end

  # Get the linked tenant
  # @return [Tenant]
  def tenant
    @tenant ||=
      if tenant_id.nil?
                        nil
      else
        Tenant.find_by(id: tenant_id)
      end
  end

  # Get the linked server.
  # @return [Server]
  def server
    @server ||=
      if server_id.nil?
        nil
      else
        Server.find(server_id)
      end
  end

  # Update the linked server.
  # @param [Server] obj
  # @return [Server]
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

  # Save pending changes to the data store.
  # @raise [RecordNotSaved] when data validation fails.
  def save!
    raise RecordNotSaved.new('Cannot update id field', self) if id_changed? && !id_was.nil?
    raise RecordNotSaved.new('Cannot update voice_bridge field', self) if voice_bridge_changed?
    raise RecordNotSaved.new('Meeting id must be set', self) if id.nil?

    with_connection do |redis|
      meeting_key = key
      redis.multi do |transaction|
        transaction.hset(meeting_key, 'server_id', server_id) if server_id_changed?
        transaction.sadd('meetings', id) if id_changed?
      end
    end

    # Superclass bookkeeping
    super
  end

  # Remove the Meeting from the data store
  # @raise [RecordNotDestroyed] when the object contains data that has not been saved.
  def destroy!
    raise RecordNotDestroyed.new('Object is not persisted', self) unless persisted?
    raise RecordNotDestroyed.new('Object has uncommitted changes', self) if changed?

    with_connection do |redis|
      redis.multi do |transaction|
        transaction.del(key)
        transaction.srem('meetings', id)
        transaction.hdel('voice_bridges', voice_bridge) unless voice_bridge.nil?
      end
    end

    # Superclass bookkeeping
    super
  end

  # Atomic operation to either find an existing meeting, or create one assigned to a specific server.
  #
  # This is intended for use with the BigBlueButton +create+ api command.
  # @param [String] id the +meetingId+ parameter from the BigBlueButton create call.
  # @param [Server] server the Server to create the meeting on (see {Server.find_available}).
  # @param [String] moderator_pw the +moderatorPW+ parameter from the BigBlueButton create call.
  # @param [String] voice_bridge the +voiceBridge+ parameter from the BigBlueButton create call.
  # @return [Meeting]
  # @raise [ArgumentError] when parameter validation of the +id+ or +server+ fails.
  # @raise [ConcurrentModificationError] if other changes to the db invalidate the call. (It should be retried.)
  # @raise Errors generated by the {allocate_voice_bridge} method.
  def self.find_or_create_with_server(id, server, moderator_pw, voice_bridge = nil, tenant_id = nil)
    raise ArgumentError, 'id is nil' if id.nil?
    raise ArgumentError, "Provided server doesn't have an id" if server.nil? || server.id.nil?

    meeting_key = key(id)
    with_connection do |redis|
      redis.watch('meetings') do
        hash = redis.hgetall(meeting_key)
        unless hash.empty?
          hash[:id] = id
          hash[:server] = server if server.id == hash['server_id']
          redis.unwatch
          logger.debug { "Meeting find_or_create: loaded existing meeting on server_id=#{hash['server_id']}" }
          return new.init_with_attributes(hash)
        end

        voice_bridge = allocate_voice_bridge(id, voice_bridge)

        created, _password_set, _voice_bridge_set, hash, _sadd_id = redis.multi do |transaction|
          transaction.hsetnx(meeting_key, 'server_id', server.id)
          transaction.hsetnx(meeting_key, 'moderator_pw', moderator_pw)
          transaction.hsetnx(meeting_key, 'voice_bridge', voice_bridge)
          transaction.hgetall(meeting_key)
          transaction.sadd('meetings', id)
          transaction.hsetnx(meeting_key, 'tenant_id', tenant_id)
        end

        raise ConcurrentModificationError.new('Meetings list concurrently modified', self) if created.nil?

        logger.debug { "Meeting find_or_create: created=#{created} on server_id=#{hash['server_id']} (wanted #{server.id})" }

        hash[:id] = id
        hash[:server] = server if server.id == hash['server_id']
        new.init_with_attributes(hash)
      end
    end
  end

  # Atomic operation to either find an existing meeting or create one, with automatic retries
  #
  # A helper function to retry the {find_or_create_with_server} method in the case of {ConcurrentModificationError}
  # until it runs to completion.
  #
  # All the parameters, return value, etc., are the same as the {find_or_create_with_server} method.
  def self.find_or_create_with_server!(id, server, moderator_pw, voice_bridge = nil, tenant_id = nil)
    loop do
      break find_or_create_with_server(id, server, moderator_pw, voice_bridge, tenant_id)
    rescue ConcurrentModificationError => e
      logger.debug(e)
      retry
    end
  end

  # Allocate a voice bridge number for this meeting.
  #
  # Try the provided number first, if configured to do so. This retries several times until it generates a non-conflicting number.
  # This method is intended to be used internally by the {find_or_create_with_server} method, not be called by external code.
  #
  # @param [String] meeting_id The +meetingId+ parameter from the BigBlueButton create call.
  # @param [String] voice_bridge The +voiceBridge+ parameter from the BigBlueButton create call, if present.
  # @return [String] The voice bridge number that was allocated for this meeting.
  # @raise [StandardError] A non-conflicting voice bridge number could not be generated.
  def self.allocate_voice_bridge(meeting_id, voice_bridge = nil)
    voice_bridge_len = Rails.configuration.x.voice_bridge_len
    use_external_voice_bridge = Rails.configuration.x.use_external_voice_bridge

    # In order to make consistent random pin numbers, use the provided meeting as the seed. Ruby's 'Random' PRNG takes a 128bit
    # integer as seed. Create one from a truncated hash of the meeting id.
    seed = Digest::SHA256.digest(meeting_id).unpack('QQ').inject { |val, n| (val << 64) | n }
    prng = Random.new(seed)
    tries = 0
    with_connection do |redis|
      loop do
        # @todo what exception class should this be?
        raise "Failed to allocate conference number for meeting #{meeting_id} after #{tries} tries" if tries >= 10

        # Use the externally provided conference number on the first try if configured to allow it.
        unless tries.zero? && use_external_voice_bridge && voice_bridge.present?
          # Create a new random conference number. First digit can't be 0...
          voice_bridge = prng.rand(1..9).to_s
          # Remaining digits can be anything
          (voice_bridge_len - 1).times do
            voice_bridge << prng.rand(0..9).to_s
          end
        end
        tries += 1
        logger.debug { "Trying to allocate voice bridge number #{voice_bridge}, try #{tries}" }

        _created, allocated_meeting_id = redis.multi do |transaction|
          transaction.hsetnx('voice_bridges', voice_bridge, meeting_id)
          transaction.hget('voice_bridges', voice_bridge)
        end

        break voice_bridge if allocated_meeting_id == meeting_id
      end
    end
  end

  # Look up a meeting by ID
  # @param [String] id the Meeting {id}.
  # @return [Meeting]
  # @raise [RecordNotFound] no meeting with the provided ID exists.
  def self.find(id, tenant_id = nil)
    with_connection do |redis|
      hash = redis.hgetall(key(id))

      raise RecordNotFound.new("Couldn't find Meeting with id=#{id}", name, id) if hash.blank?

      raise RecordNotFound.new("Couldn't find Meeting with id=#{id} and tenant_id=#{tenant_id}", name, id) if tenant_id.to_i != hash['tenant_id'].to_i

      hash[:id] = id
      new.init_with_attributes(hash)
    end
  end

  # Find a meeting by voice bridge number
  # @param [String] number the +voiceBridge+ number.
  # @return [Meeting]
  # @raise [RecordNotFound] when the voice bridge number does not correspond to an existing Meeting.
  def self.find_by_voice_bridge(number)
    with_connection do |redis|
      id = redis.hget('voice_bridges', number)
      raise RecordNotFound.new("Couldn't find Meeting id for voice_bridge=#{number}", name) if id.nil?

      find(id)
    end
  end

  # @return [Array[Meeting]]
  def self.all(tenant_id = nil)
    meetings = []
    with_connection do |redis|
      ids = redis.smembers('meetings')
      ids.each do |id|
        hash = redis.hgetall(key(id))
        next if hash.blank?

        if tenant_id.present?
          # Only fetch meetings for particular Tenant
          next if tenant_id.to_i != hash['tenant_id'].to_i
        elsif hash['tenant_id'].present?
          next
        end
        # Only fetch meetings without Tenant

        hash[:id] = id
        meetings << new.init_with_attributes(hash)
      end
    end
    meetings
  end

  # @return [String] the key of the Redis hash used to persist Meeting attributes.
  def self.key(id)
    "meeting:#{id}"
  end

  # @return [String] the key of the Redis hash used to persist Meeting attributes.
  def key
    self.class.key(id)
  end
end
