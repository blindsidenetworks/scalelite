# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '>= 2.6.5'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.0.2', '>= 6.0.2.1'
# Use Puma as the app server
gem 'puma', '~> 4.3'
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.7'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Redis connection setup for live session (server and meeting) tracking
gem 'connection_pool', '~> 2.2.2'
gem 'hiredis', '~> 0.6.3'
gem 'redis', '~> 4.1.3'
gem 'redis-namespace', '~> 1.7.0'

# Use postgresql as the database for Active Record
gem 'pg'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.2', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

# Generates a terminal table
gem 'tabulo', '~> 2.3.0'

# Used by recording watch task. Version limit is for compat with rails auto-reloader.
gem 'listen', '>= 3.0.5', '< 3.2'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]

  # Allow using sqlite as the database for Active Record in development/test env
  gem 'sqlite3'

  gem 'dotenv-rails'
  gem 'factory_bot_rails'
end

group :development do
  gem 'rubocop', '~> 0.79.0', require: false
  gem 'rubocop-rails', '~> 2.4.0', require: false
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
end

group :test do
  gem 'fakeredis', github: 'guilleiguaran/fakeredis', ref: '2ebe19229954c7234bed019a0c5d28d5cf5b40f6'
  gem 'minitest-stub_any_instance'
  gem 'webmock'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
