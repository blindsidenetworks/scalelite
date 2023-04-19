# frozen_string_literal: true

# class Tenant < ApplicationRecord
#   SECRETS_SEPARATOR = ':'
#
#   validates :name, presence: true
#   validates :secrets, presence: true
#
#   validates :name, uniqueness: true
#   validates :secrets, uniqueness: true
#
#   def secrets_array
#     secrets.split(SECRETS_SEPARATOR)
#   end
# end

class Tenant < ApplicationRedisRecord
  SECRETS_SEPARATOR = ':'

  define_attribute_methods :id, :name, :secrets

  # Unique ID for this tenant
  application_redis_attr :id

  # The name of the tenant that should match the subdomain
  application_redis_attr :name

  # Shared secrets for making API requests for this tenant (: separated)
  application_redis_attr :secrets

  def save!
    with_connection do |redis|
      raise RecordNotSaved.new('Cannot update id field', self) if id_changed? && !@new_record

      # Default values
      self.id = SecureRandom.uuid if id.nil?

      redis.watch('tenants') do
        exists = redis.sismember('tenants', id)
        raise RecordNotSaved.new("Tenant already exists with id '#{id}'", self) if id_changed? && exists
        raise RecordNotSaved.new("Tenant with id '#{id}' is deleted", self) if !id_changed? && !exists

        tenant_key = key
        redis.multi do |pipeline|
          pipeline.hset(tenant_key, 'name', name) if name_changed?
          pipeline.hset(tenant_key, 'secrets', secrets) if secrets_changed?
          pipeline.sadd('tenants', id) if id_changed?
        end
      end
    end

    # Superclass bookkeeping
    super
  end

  def secrets_array
    @secrets.split(SECRETS_SEPARATOR)
  end

  # @return [String] the key of the Redis hash used to persist Tenant attributes.
  def self.key(id)
    "tenant:#{id}"
  end

  # @return [String] the key of the Redis hash used to persist Tenant attributes.
  def key
    self.class.key(id)
  end
end
