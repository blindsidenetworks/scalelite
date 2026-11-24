# frozen_string_literal: true

class Tenant < ApplicationRedisRecord
  SECRETS_SEPARATOR = ':'

  define_attribute_methods :id, :name, :secrets, :lrs_endpoint, :lrs_username, :lrs_password,
                           :kc_token_url, :kc_client_id, :kc_client_secret, :kc_username, :kc_password,
                           :recording_dir

  # What a recording directory may be made of. It ends up in file operations and in a symbolic link, so it
  # is kept to an absolute path that needs no quoting anywhere and cannot climb out of itself.
  RECORDING_DIR_PATTERN = %r{\A(/[A-Za-z0-9._-]+)+\z}

  # Unique ID for this tenant
  application_redis_attr :id

  # The name of the tenant that should match the subdomain
  application_redis_attr :name

  # Shared secrets for making API requests for this tenant (: separated)
  application_redis_attr :secrets

  # A directory of its own for the recordings of this tenant, in place of the publish and unpublish
  # directories all recordings are kept in. Only used while RECORDING_DIR_PER_TENANT is set; unset means the
  # tenant keeps its recordings where everybody does. See docs/recording-directories.md.
  application_redis_attr :recording_dir

  # Custom LRS work
  application_redis_attr :lrs_endpoint
  application_redis_attr :lrs_username
  application_redis_attr :lrs_password
  application_redis_attr :kc_token_url
  application_redis_attr :kc_client_id
  application_redis_attr :kc_client_secret
  application_redis_attr :kc_username
  application_redis_attr :kc_password

  def save!
    with_connection do |redis|
      raise RecordNotSaved.new('Cannot update id field', self) if id_changed? && !@new_record

      # Default values
      self.id = SecureRandom.uuid if id.nil?

      redis.watch('tenants') do
        exists = redis.sismember('tenants', id)
        raise RecordNotSaved.new("Tenant already exists with id '#{id}'", self) if id_changed? && exists
        raise RecordNotSaved.new("Tenant with id '#{id}' is deleted", self) if !id_changed? && !exists

        id_key = key
        names_key = name_key
        old_names_key = self.class.name_key(name_was)
        redis.multi do |pipeline|
          pipeline.hset(names_key, 'id', id) if id_changed? || name_changed? # Create tenant id -> name index
          pipeline.del(old_names_key) if !id_changed? && name_changed? # Delete the old name key if it's not a new record and the name was updated
          pipeline.hset(id_key, 'name', name) if name_changed?
          pipeline.hset(id_key, 'secrets', secrets) if secrets_changed?
          # An empty directory is removed rather than stored as an empty string, so that "none" is one state
          if recording_dir_changed?
            recording_dir.present? ? pipeline.hset(id_key, 'recording_dir', recording_dir) : pipeline.hdel(id_key, 'recording_dir')
          end
          pipeline.hset(id_key, 'lrs_endpoint', lrs_endpoint) if lrs_endpoint_changed?
          pipeline.hset(id_key, 'lrs_username', lrs_username) if lrs_username_changed?
          pipeline.hset(id_key, 'lrs_password', lrs_password) if lrs_password_changed?
          pipeline.hset(id_key, 'kc_token_url', kc_token_url) if kc_token_url_changed?
          pipeline.hset(id_key, 'kc_client_id', kc_client_id) if kc_client_id_changed?
          pipeline.hset(id_key, 'kc_client_secret', kc_client_secret) if kc_client_secret_changed?
          pipeline.hset(id_key, 'kc_username', kc_username) if kc_username_changed?
          pipeline.hset(id_key, 'kc_password', kc_password) if kc_password_changed?
          pipeline.sadd?('tenants', id) if id_changed?
        end
      end
    end

    # Superclass bookkeeping
    super
  end

  # Look up a tenant by ID
  # @param [String] id the Tenant {id}.
  # @return [Tenant]
  # @raise [RecordNotFound] no tenant with the provided ID exists.
  def self.find(id)
    with_connection do |redis|
      hash = redis.hgetall(key(id))

      raise RecordNotFound.new("Couldn't find Tenant with id=#{id}", name, id) if hash.blank?

      hash[:id] = id

      new.init_with_attributes(hash)
    end
  end

  # Look up a tenant by ID
  # @param [String] name the Tenant {tenant_name}.
  # @return [Tenant]
  # @raise [RecordNotFound] no tenant with the provided name exists.
  def self.find_by_name(tenant_name)
    with_connection do |redis|
      # Use the name -> id index to get the id for the given name
      name_hash = redis.hgetall(name_key(tenant_name))
      return nil if name_hash.blank?
      # Look up the true values using the id from above
      hash = redis.hgetall(key(name_hash["id"]))
      return nil if hash.blank?

      hash[:id] = name_hash["id"]
      new.init_with_attributes(hash)
    end
  end

  # Returns all tenants
  # @return [Array[Tenant]]
  def self.all
    tenants = []
    with_connection do |redis|
      ids = redis.smembers('tenants')
      return tenants if ids.blank?

      ids.each do |id|
        hash = redis.hgetall(key(id))

        next if hash.blank?

        hash['id'] = id
        tenants << new.init_with_attributes(hash)
      end
    end
    tenants
  end

  # Remove the Tenant from the data store
  # @raise [RecordNotDestroyed] when the object contains data that has not been saved.
  def destroy!
    raise RecordNotDestroyed.new('Object is not persisted', self) unless persisted?
    raise RecordNotDestroyed.new('Object has uncommitted changes', self) if changed?

    with_connection do |redis|
      redis.multi do |transaction|
        transaction.del(key)
        transaction.del(name_key)
        transaction.srem?('tenants', id)
      end
    end

    # Superclass bookkeeping
    super
  end

  def secrets_array
    secrets.split(SECRETS_SEPARATOR)
  end

  # Read a recording directory as an operator supplied it. Blank means the tenant has none of its own.
  #
  # @param [String, nil] value
  # @return [String, nil] the directory without a trailing slash, or nil for none.
  # @raise [ArgumentError] the value is not an absolute path made of plain names.
  def self.parse_recording_dir(value)
    return nil if value.blank?

    dir = value.to_s.strip.chomp('/')
    unless dir.match?(RECORDING_DIR_PATTERN) && !dir.split('/').intersect?(%w[. ..])
      raise ArgumentError, 'Recording directory must be an absolute path made of letters, digits, ".", "_" and "-"'
    end

    dir
  end

  # @return [String] the key of the Redis hash used to persist Tenant attributes.
  def self.key(id)
    "tenant:#{id}"
  end

  # @return [String] the key of the Redis hash used to persist Tenant attributes.
  def self.name_key(name)
    "tenant_name:#{name}"
  end

  # @return [String] the key of the Redis hash used to persist Tenant attributes.
  def key
    self.class.key(id)
  end

  # @return [String] the key of the Redis hash used to persist Tenant attributes.
  def name_key
    self.class.name_key(name)
  end
end
