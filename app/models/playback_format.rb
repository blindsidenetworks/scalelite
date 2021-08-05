# frozen_string_literal: true

class PlaybackFormat < ApplicationRecord
  belongs_to :recording
  has_many :thumbnails, dependent: :destroy
  default_scope { order(format: :asc) }

  class ProtectorTokenError < RuntimeError; end

  PROTECTOR_TOKEN_KEY_PREFIX = 'protector_token_'

  # Create a one-time-use protection token for this playback format
  def create_protector_token
    token = SecureRandom.hex(32)
    payload = {
      'record_id' => recording.record_id,
      'format' => self.format,
    }.to_json

    key = "#{PROTECTOR_TOKEN_KEY_PREFIX}#{token}"
    RedisStore.with_connection do |redis|
      redis.multi do
        redis.set(key, payload)
        redis.expire(key, Rails.configuration.x.recording_token_ttl)
      end
    end

    token
  end

  # Lookup and invalidate a one-time-use protection token, and return the playback format it is for
  def self.consume_protector_token(token)
    raise ProtectorTokenError, 'Token format is invalid' if token.blank? || !/\A[0-9a-f]{64}\z/.match?(token)

    key = "#{PROTECTOR_TOKEN_KEY_PREFIX}#{token}"
    result = RedisStore.with_connection do |redis|
      redis.multi do
        redis.get(key)
        redis.del(key)
      end
    end
    raise ProtectorTokenError, 'Token not found' if result[0].blank?

    JSON.parse(result[0])
  end
end
