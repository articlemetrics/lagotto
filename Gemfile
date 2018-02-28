source 'http://rubygems.org'

gem 'rails', '~> 4.2.7.1'
gem 'mysql2', '0.3.18'

gem "dotenv", '~> 1.0.2'
gem 'sidekiq', '~> 3.3.0'
gem 'sinatra'
gem 'rake', '~> 10.4.2'
gem "whenever", "~> 0.9.0", require: false
gem 'parse-cron', '~> 0.1.4'
gem "mail", "~> 2.6.1"
gem 'nondestructive_migrations', '~> 1.1'
gem 'immigrant', '~> 0.3.4'
gem "state_machine", "~> 1.2.0", :git => 'https://github.com/fly1tkg/state_machine.git', :branch => 'issue/334'
gem "logstash-logger", "~> 0.7.0"
gem 'bugsnag', '~> 2.8.6'
gem 'sentry-raven', '~> 0.14.0'

gem "faraday", "~> 0.9.0"
gem "faraday_middleware", "~> 0.9.1"
gem 'excon', '~> 0.45.3'
gem 'addressable', "~> 2.3.5"
gem 'postrank-uri', '~> 1.0.18'
gem "multi_xml", "~> 0.5.5"
gem "nokogiri", "~> 1.8.1"
gem "multi_json", "~> 1.10.1"
gem "oj", "~> 2.10.4"
gem 'safe_yaml', '~> 1.0.4'
gem 'hashie', '~> 3.3.2'
gem 'rubyzip',  "~> 1.2.1", :require => 'zip'

gem "devise", "~> 3.4.1"
gem "omniauth-persona"
gem "omniauth-cas", "~> 1.1.0"
gem 'omniauth-github', '~> 1.1.2'
gem "omniauth-orcid", "~> 1.0"
gem 'omniauth', '~> 1.2.2'
gem 'cancancan', '~> 1.9.2'
gem "validates_timeliness", "~> 3.0.14"
gem "strip_attributes", "~> 1.2"
gem 'draper', '~> 2.1.0'
gem 'jbuilder', '~> 2.2.12'
gem "swagger-docs", "~> 0.1.9"
gem 'swagger-ui_rails', '~> 0.1.7'
gem "dalli", "~> 2.7.0"
gem 'will_paginate', '3.0.7'
gem "will_paginate-bootstrap", "~> 1.0.1"
gem "simple_form", "~> 3.1.0"
gem 'nilify_blanks', '~> 1.2.0'
gem "github-markdown", "~> 0.6.3"
gem "rouge", "~> 1.7.2"
gem 'dotiw', '~> 2.0'

gem 'sprockets-rails', '~> 2.2.0', :require => 'sprockets/railtie'
gem 'sass-rails', '~> 4.0.4'
gem "uglifier", "~> 2.5.3"
gem 'coffee-rails', '~> 4.1.0'
gem "ember-cli-rails"

gem "zenodo", "~> 0.0.8"

group :development do
  gem 'pry-rails', '~> 0.3.2'
  gem 'better_errors', '~> 2.0.0'
  gem 'binding_of_caller', '~> 0.7.2'
  gem 'capistrano', '~> 3.4.1'
  gem 'capistrano-rails', '~> 1.1.1', :require => false
  gem 'capistrano-bundler', '~> 1.1.2', :require => false
  gem 'capistrano-npm', '~> 1.0.0'
  # gem 'spring', '~> 1.1.2'
  gem 'hologram', '~> 1.3.1'
end

group :test do
  gem "factory_girl_rails", "~> 4.5.0", :require => false
  gem "capybara", "~> 2.4.4"
  gem 'capybara-screenshot', '~> 1.0.3'
  gem 'colorize', '~> 0.8.1'
  gem "database_cleaner", "~> 1.3.0"
  gem "launchy", "~> 2.4.2"
  gem "email_spec", "~> 1.6.0"
  gem "rack-test", "~> 0.6.2", :require => "rack/test"
  gem "simplecov", "~> 0.9.1", :require => false
  gem 'codeclimate-test-reporter', '~> 0.4.1', :require => nil
  gem "shoulda-matchers", "~> 2.7.0", :require => false
  gem "webmock", "~> 1.20.0"
  gem 'vcr', '~> 2.9.3'
  gem "poltergeist", "~> 1.6.0"
  gem "with_env", "~> 1.1.0"
end

group :test, :development do
  gem 'byebug'
  gem "rspec-rails", "~> 3.1.0"
  # gem 'spring-commands-rspec', '~> 1.0.4'
  gem 'teaspoon-jasmine', '~> 2.2.0'
  gem "brakeman", "~> 2.6.0", :require => false
  gem 'rubocop', '~> 0.49.0'
  gem 'bullet', '~> 4.14.0'
end

gem 'rack-mini-profiler', '~> 0.10.1', require: false
gem 'puma'
