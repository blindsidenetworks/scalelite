# frozen_string_literal: true

desc('livenessProbe')
task liveness: :environment do
  Rails.logger.info('success')
end
