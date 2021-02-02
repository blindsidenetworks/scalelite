# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
# require 'active_job/railtie'
require 'active_record/railtie'
# require 'active_storage/engine'
require 'action_controller/railtie'
# require 'action_mailer/railtie'
# require 'action_mailbox/engine'
# require 'action_text/engine'
require 'action_view/railtie'
# require 'action_cable/engine'
# require 'sprockets/railtie'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Scalelite
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults(6.0)

    config.eager_load_paths << Rails.root.join('lib')

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Read the file config/redis_store.yml as per-environment configuration with erb
    config.x.redis_store = config_for(:redis_store)

    # Build number returned in the /bigbluebutton/api response
    config.x.build_number = ENV['BUILD_NUMBER']

    # Secret used to verify /bigbluebutton/api requests
    config.x.loadbalancer_secret = ENV['LOADBALANCER_SECRET']

    # Defaults to 0 since nil/"".to_i = 0
    config.x.max_meeting_duration = ENV['MAX_MEETING_DURATION'].to_i

    # Number of times poller needs to successfully reach offline server for it to
    # be considered online again
    config.x.server_healthy_threshold = ENV.fetch('SERVER_HEALTHY_THRESHOLD', '1').to_i

    # Number of times poller needs to fail to reach online server for it to panic the server
    # and set it to offline
    config.x.server_unhealthy_threshold = ENV.fetch('SERVER_UNHEALTHY_THRESHOLD', '2').to_i

    # Directory to monitor for recordings transferred from BigBlueButton servers
    config.x.recording_spool_dir = File.absolute_path(
      ENV.fetch('RECORDING_SPOOL_DIR') { '/var/bigbluebutton/spool' }
    )
    # Working directory for temporary files when extracting recordings
    config.x.recording_work_dir = File.absolute_path(
      ENV.fetch('RECORDING_WORK_DIR') { '/var/bigbluebutton/recording/scalelite' }
    )
    # Published recording directory
    config.x.recording_publish_dir = File.absolute_path(
      ENV.fetch('RECORDING_PUBLISH_DIR') { '/var/bigbluebutton/published' }
    )

    # Unpublished recording directory
    config.x.recording_unpublish_dir = File.absolute_path(
      ENV.fetch('RECORDING_UNPUBLISH_DIR') { '/var/bigbluebutton/unpublished' }
    )
  end
end
