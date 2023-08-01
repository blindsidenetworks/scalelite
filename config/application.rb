# frozen_string_literal: true

require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie' unless 'true'.casecmp?(ENV['DB_DISABLED'])
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
require 'active_support/time'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Scalelite
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.eager_load_paths << Rails.root.join('lib')

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Read the file config/redis_store.yml as per-environment configuration with erb
    config.x.redis_store = config_for(:redis_store)

    # Build number returned in the /bigbluebutton/api response
    config.x.build_number = ENV.fetch('BUILD_NUMBER', nil)

    # Secrets used to verify /bigbluebutton/api requests
    config.x.loadbalancer_secrets = []
    config.x.loadbalancer_secrets.push(ENV['LOADBALANCER_SECRET']) if ENV['LOADBALANCER_SECRET']
    config.x.loadbalancer_secrets.concat(ENV['LOADBALANCER_SECRETS'].split(':')) if ENV['LOADBALANCER_SECRETS']

    # Algorithms used for calculating checksum [SHA1|SHA256|...]
    config.x.loadbalancer_checksum_algorithm = ENV.fetch('LOADBALANCER_CHECKSUM_ALGORITHM', 'SHA1:SHA256:SHA512')
    config.x.loadbalancer_checksum_algorithms = config.x.loadbalancer_checksum_algorithm.split(':')

    # Defaults to 0 since nil/"".to_i = 0
    config.x.max_meeting_duration = ENV['MAX_MEETING_DURATION'].to_i

    # Number of times poller needs to successfully reach offline server for it to
    # be considered online again
    config.x.server_healthy_threshold = ENV.fetch('SERVER_HEALTHY_THRESHOLD', '1').to_i

    # Number of times poller needs to fail to reach online server for it to panic the server
    # and set it to offline
    config.x.server_unhealthy_threshold = ENV.fetch('SERVER_UNHEALTHY_THRESHOLD', '2').to_i

    # Request connection timeout. This is the timeout for the initial TCP/TLS connection, not including
    # waiting for a response.
    config.x.open_timeout = ENV.fetch('CONNECT_TIMEOUT', '5').to_f

    # Request response timeout. This is the timeout for waiting for a response after the connection has
    # been established and the request has been sent.
    config.x.read_timeout = ENV.fetch('RESPONSE_TIMEOUT', '10').to_f

    # Directory to monitor for recordings transferred from BigBlueButton servers
    config.x.recording_spool_dir = File.absolute_path(
      ENV.fetch('RECORDING_SPOOL_DIR', '/var/bigbluebutton/spool')
    )
    # Working directory for temporary files when extracting recordings
    config.x.recording_work_dir = File.absolute_path(
      ENV.fetch('RECORDING_WORK_DIR', '/var/bigbluebutton/recording/scalelite')
    )
    # Published recording directory
    config.x.recording_publish_dir = File.absolute_path(
      ENV.fetch('RECORDING_PUBLISH_DIR', '/var/bigbluebutton/published')
    )

    # Unpublished recording directory
    config.x.recording_unpublish_dir = File.absolute_path(
      ENV.fetch('RECORDING_UNPUBLISH_DIR', '/var/bigbluebutton/unpublished')
    )

    # Minimum user count of a meeting, used for calculating server load. Defaults to 15.
    config.x.load_min_user_count = ENV.fetch('LOAD_MIN_USER_COUNT', 15).to_i

    # The time(in minutes) until the `load_min_user_count` will be used for calculating server load
    config.x.load_join_buffer_time = ENV.fetch('LOAD_JOIN_BUFFER_TIME', 15).to_i.minutes

    # Whether to generate ids for servers based on the hostname rather than random UUIDs. Default to false.
    config.x.server_id_is_hostname = ENV.fetch('SERVER_ID_IS_HOSTNAME', 'false').casecmp?('true')

    # Recording feature will be disabled, if set to 'true'. Defaults to false.
    config.x.recording_disabled = ENV.fetch('RECORDING_DISABLED', 'false').casecmp?('true')
    # List of BBB server attributes that should not be modified by create API call
    config.x.create_exclude_params = ENV['CREATE_EXCLUDE_PARAMS']&.split(',') || []

    # List of BBB server attributes that should not be modified by join API call
    config.x.join_exclude_params = ENV['JOIN_EXCLUDE_PARAMS']&.split(',') || []

    # Recordings imported will be unpublished by default, if set to 'true'. Defaults to false.
    config.x.recording_import_unpublished = ENV.fetch('RECORDING_IMPORT_UNPUBLISHED', 'false').casecmp?('true')

    # Multitenancy values
    config.x.multitenancy_enabled = ENV.fetch('MULTITENANCY_ENABLED', 'false').casecmp?('true')

    # Scalelite Host name
    config.x.url_host = ENV.fetch('URL_HOST', nil)

    # DB connection retry attempt counts
    config.x.db_connection_retry_count = ENV.fetch('DB_CONNECTION_RETRY_COUNT', '3').to_i

    # Prevents get_recordings api from returning all recordings when recordID is not specified in the request, if set to 'true'.
    # Defaults to false.
    config.x.get_recordings_api_filtered = ENV.fetch('GET_RECORDINGS_API_FILTERED', 'false').casecmp?('true')

    # Poller threads value, defaults to 5. Needs to be adjusted as per the number of servers to be polled
    config.x.poller_threads = ENV.fetch('POLLER_THREADS', 5).to_i

    # Poller wait timeout value, timeout value set for the poller to finish polling a server. Defaults to 10.
    config.x.poller_wait_timeout = ENV.fetch('POLLER_WAIT_TIMEOUT', 10).to_i

    # Recording playback formats handled by Scalelite
    config.x.recording_playback_formats = ENV.fetch('RECORDING_PLAYBACK_FORMATS',
                                                    'presentation:video:screenshare:podcast:notes:capture').split(':')

    # Recordings will proctected, if set to 'true'. Defaults to false.
    config.x.protected_recordings_enabled = ENV.fetch('PROTECTED_RECORDINGS_ENABLED', 'false').casecmp?('true')
    # Protected recordings token timeout in minutes. Defaults to 60 (1 hour)
    config.x.recording_token_ttl = ENV.fetch('PROTECTED_RECORDINGS_TOKEN_TIMEOUT', '60').to_i.minutes
    # Protected recordings resource access cookie timeout in minutes. Defaults to 360 (6 hours)
    config.x.recording_cookie_ttl = ENV.fetch('PROTECTED_RECORDINGS_TIMEOUT', '360').to_i.minutes

    config.i18n.default_locale = ENV.fetch('DEFAULT_LOCALE', 'en')

    # Comma separated list of create params that can be overridden by the client
    config.x.default_create_params = ENV.fetch('DEFAULT_CREATE_PARAMS', '')
                                        .split(',').to_h { |param| param.split('=', 2) }.symbolize_keys
    # Comma separated list of create params that CANT be overridden by the client
    config.x.override_create_params = ENV.fetch('OVERRIDE_CREATE_PARAMS', '')
                                         .split(',').to_h { |param| param.split('=', 2) }.symbolize_keys
    # Comma separated list of join params that can be overridden by the client
    config.x.default_join_params = ENV.fetch('DEFAULT_JOIN_PARAMS', '')
                                      .split(',').to_h { |param| param.split('=', 2) }.symbolize_keys
    # Comma separated list of join params that CANT be overridden by the client
    config.x.override_join_params = ENV.fetch('OVERRIDE_JOIN_PARAMS', '')
                                       .split(',').to_h { |param| param.split('=', 2) }.symbolize_keys

    # The length (number of digits) of voice bridge numbers to allocate
    config.x.voice_bridge_len = ENV.fetch('VOICE_BRIDGE_LEN', 9).to_i

    # Whether to try to use the voice bridge number requested on the BigBlueButton create API call.
    config.x.use_external_voice_bridge = ENV.fetch('USE_EXTERNAL_VOICE_BRIDGE', 'false').casecmp?('true')

    # Password to access the freeswitch dialplan API
    config.x.fsapi_password = ENV.fetch('FSAPI_PASSWORD', config.x.loadbalancer_secrets[0])

    # Maximum amount of time to allow bridged calls to stay connected for. Defaults to same as max meeting duration.
    config.x.fsapi_max_duration = ENV.fetch('FSAPI_MAX_DURATION', config.x.max_meeting_duration).to_i
  end
end
