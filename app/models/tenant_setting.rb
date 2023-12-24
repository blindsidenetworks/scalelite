# frozen_string_literal: true

class TenantSetting < ApplicationRedisRecord
  define_attribute_methods :id, :param, :value, :override, :tenant_id

  # Unique ID for this tenant
  application_redis_attr :id

  # The name of the param
  application_redis_attr :param

  # The value of the param
  application_redis_attr :value

  # Whether the param should override the param if it's passed in
  application_redis_attr :override

  # The tenant that the settings belong to
  application_redis_attr :tenant_id

  def save!
    with_connection do |redis|
      raise RecordNotSaved.new('Cannot update id field', self) if id_changed? && !@new_record

      # Default values
      self.id = SecureRandom.uuid if id.nil?

      redis.watch('tenant_settings') do
        exists = redis.sismember("tenant_settings:#{tenant_id}", id)
        raise RecordNotSaved.new("TenantSetting already exists with id '#{id}'", self) if id_changed? && exists
        raise RecordNotSaved.new("TenantSetting with id '#{id}' is deleted", self) if !id_changed? && !exists

        redis.multi do |pipeline|
          pipeline.hset(key, 'param', param) if param_changed?
          pipeline.hset(key, 'value', value) if value_changed?
          pipeline.hset(key, 'override', override) if override_changed?
          pipeline.hset(key, 'tenant_id', tenant_id) if tenant_id_changed?

          pipeline.sadd?("tenant_settings:#{tenant_id}", id) if id_changed?
        end
      end
    end

    # Superclass bookkeeping
    super
  end

  # Look up a TenentSetting by ID
  # @param [String] id the TenentSetting {id}.
  # @return [TenantSetting]
  # @raise [RecordNotFound] no TenentSetting with the provided ID exists.
  def self.find(id)
    with_connection do |redis|
      hash = redis.hgetall(key(id))

      raise RecordNotFound.new("Couldn't find TenantSetting with id=#{id}", name, id) if hash.blank?

      hash[:id] = id

      new.init_with_attributes(hash)
    end
  end

  # Returns all tenant settings for a given tenant
  # @return [Array[TenantSetting]]
  def self.all(tenant_id)
    settings = []
    with_connection do |redis|
      ids = redis.smembers("tenant_settings:#{tenant_id}")
      return settings if ids.blank?

      ids.each do |id|
        hash = redis.hgetall(key(id))

        next if hash.blank?

        hash['id'] = id
        settings << new.init_with_attributes(hash)
      end
    end
    settings
  end

  # Remove the TenantSetting from the data store
  # @raise [RecordNotDestroyed] when the object contains data that has not been saved.
  def destroy!
    raise RecordNotDestroyed.new('Object is not persisted', self) unless persisted?
    raise RecordNotDestroyed.new('Object has uncommitted changes', self) if changed?

    with_connection do |redis|
      redis.multi do |transaction|
        transaction.del(key)
        transaction.srem("tenant_settings:#{tenant_id}", id)
      end
    end

    # Superclass bookkeeping
    super
  end

  # Returns all 2 separate arrays for settings that are either default or override
  # @return {param1: defaultValue}, {param2: overrideValue}
  def self.defaults_and_overrides(tenant_id)
    default = {}
    override = {}

    return [default, override] if tenant_id.nil?

    settings = all(tenant_id)

    settings.each do |setting|
      if setting.override == "true"
        override[setting.param.to_sym] = setting.value
        next
      end
      default[setting.param.to_sym] = setting.value
    end

    [default, override]
  end

  # @return [String] the key of the Redis hash used to persist Tenant attributes.
  def self.key(id)
    "tenant_setting:#{id}"
  end

  # @return [String] the key of the Redis hash used to persist TenantSetting attributes.
  def key
    self.class.key(id)
  end
end
