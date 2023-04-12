# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '>= 3.1.0'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 6.1', '>= 6.1.7.3'
# Use Puma as the app server
gem 'puma', '~> 6.2', '>= 6.2.1'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.7'
# Use Active Model has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Redis connection setup for live session (server and meeting) tracking
gem 'connection_pool', '~> 2.4.0'
gem 'redis', '~> 4.8.0'
gem 'redis-namespace', '~> 1.10.0'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.4.4'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.16.0', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

# Generates a terminal table
gem 'tabulo', '~> 2.8.1'

gem 'jwt', '~> 2.7.0'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  # Allow using sqlite as the database for Active Record in development/test env
  gem 'sqlite3'

  gem 'dotenv-rails'
  gem 'factory_bot_rails'

  gem 'rspec-rails', '~> 5.1.2'

  gem 'rubocop', '~> 1.50.0', require: false
  gem 'rubocop-rails', '~> 2.19.0', require: false
end

group :development do
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.1'
end

group :test do
  gem 'faker'
  gem 'fakeredis', '~> 0.8'
  gem 'minitest-stub_any_instance'
  gem 'rails-controller-testing'
  gem 'webmock'
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
