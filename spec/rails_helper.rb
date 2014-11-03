# set ENV variables for testing
ENV["RAILS_ENV"] = "test"
ENV["API_KEY"] = "12345"
ENV["ADMIN_EMAIL"] = "info@example.org"
ENV["WORKERS"] = "1"
ENV["COUCHDB_URL"] = "http://localhost:5984/alm_test"
ENV["IMPORT"] = "member"

require "codeclimate-test-reporter"
CodeClimate::TestReporter.configure do |config|
  config.logger.level = Logger::WARN
end
CodeClimate::TestReporter.start

require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'shoulda-matchers'
require 'rspec/autorun'
require 'email_spec'
require 'factory_girl_rails'
require 'capybara/rspec'
require 'database_cleaner'
require 'webmock/rspec'
require "rack/test"
require 'draper/test/rspec_integration'

include WebMock::API
allowed_hosts = [/codeclimate.com/, ENV['HOSTNAME']]
WebMock.disable_net_connect!(allow: allowed_hosts, allow_localhost: true)

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

def app
  Rails.application
end

RSpec.configure do |config|
  config.include EmailSpec::Helpers
  config.include EmailSpec::Matchers
  config.include Rack::Test::Methods
  config.include FactoryGirl::Syntax::Methods
  config.include(MailerMacros)

  config.infer_spec_type_from_file_location!

  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with :truncation
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.start
    reset_email
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.fixture_path = "#{::Rails.root}/spec/fixtures/"

  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.infer_base_class_for_anonymous_controllers = false

  # Configure caching, use ":caching => true" when you need to test this
  config.around(:each) do |example|
    caching = ActionController::Base.perform_caching
    ActionController::Base.perform_caching = example.metadata[:caching]
    example.run
    Rails.cache.clear
    ActionController::Base.perform_caching = caching
  end

  def capture_stdout(&block)
    original_stdout = $stdout
    $stdout = fake = StringIO.new
    begin
      yield
    ensure
      $stdout = original_stdout
    end
    fake.string
  end
end