# frozen_string_literal: true

class HealthCheckController < ApplicationController
  def index
    @cache_expire = 10.seconds

    begin
      cache_check
      database_check
    rescue StandardError => e
      return render(plain: "Health Check Failure: #{e}")
    end

    render(plain: 'success')
  end

  private

  def cache_check
    RedisStore.with_connection do |redis|
      redis.set('__health_check_set__', 'true', ex: @cache_expire)
      redis.get('__health_check_set__')
    end
  end

  def database_check
    raise 'Database not responding' if defined?(ActiveRecord) && !ActiveRecord::Migrator.current_version
    raise 'Pending migrations' unless ActiveRecord::Migration.check_pending!.nil?
  end
end
