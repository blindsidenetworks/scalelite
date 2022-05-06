# frozen_string_literal: true

# Specifies the number of `workers` to boot in clustered mode.
# Workers are forked web server processes. If using threads and workers together
# the concurrency of the application would be max `threads` * `workers`.
# Workers do not work on JRuby or Windows (both of which do not support
# processes).
workers(ENV.fetch('WEB_CONCURRENCY', 0))

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
max_threads_count = ENV.fetch('RAILS_MAX_THREADS', 5)
min_threads_count = ENV.fetch('RAILS_MIN_THREADS') { max_threads_count }
threads(min_threads_count, max_threads_count)

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
# You can either specify `BIND` with a full address (even unix socket) or just `PORT`
bind(ENV.fetch('BIND') { "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}" })

# Specifies the `environment` that Puma will run in.
environment(ENV.fetch('RAILS_ENV', 'development'))

# Use the `preload_app!` method when specifying a `workers` number.
# This directive tells Puma to first boot the application and load code
# before forking the application. This takes advantage of Copy On Write
# process behavior so workers use less memory.
preload_app!

before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
  RedisStore.before_fork
end

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

# Allow puma to be restarted by `rails restart` command.
plugin(:tmp_restart)
