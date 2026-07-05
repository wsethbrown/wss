ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"
require "ostruct" # Ruby 3.4+ no longer autoloads OpenStruct; some tests build mock Stripe objects with it

# Configure OmniAuth for testing
OmniAuth.config.test_mode = true
OmniAuth.config.mock_auth[:default] = :invalid_credentials

# Mock OAuth responses for testing
OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new({
  provider: 'apple',
  uid: 'test_apple_uid_123',
  info: {
    email: 'test@appleid.com',
    first_name: 'Test',
    last_name: 'Apple',
    name: 'Test Apple'
  },
  extra: {
    raw_info: {
      email: 'test@appleid.com',
      first_name: 'Test',
      last_name: 'Apple'
    }
  }
})

OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
  provider: 'google_oauth2',
  uid: 'test_google_uid_456',
  info: {
    email: 'test@gmail.com',
    first_name: 'Test',
    last_name: 'Google',
    name: 'Test Google'
  },
  extra: {
    raw_info: {
      email: 'test@gmail.com',
      first_name: 'Test',
      last_name: 'Google'
    }
  }
})

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    
    # Helper method to sign in a user for tests
    def sign_in(user)
      post user_session_path, params: {
        user: {
          email: user.email,
          password: 'password'
        }
      }
    end
    
    # Helper method to create a test user
    def create_test_user(attributes = {})
      User.create!({
        email: 'test@example.com',
        password: 'password',
        password_confirmation: 'password',
        first_name: 'Test',
        last_name: 'User'
      }.merge(attributes))
    end
    
    # Helper method to create a test society
    def create_test_society(creator, attributes = {})
      Society.create!({
        name: 'Test Society',
        description: 'A test society for whiskey enthusiasts',
        location: 'Test City',
        creator: creator,
        is_private: false
      }.merge(attributes))
    end
    
    # Helper method to set up OAuth mock for different scenarios
    def setup_oauth_mock(provider, scenario = :success)
      case scenario
      when :success
        if provider == :apple
          OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new({
            provider: 'apple',
            uid: 'test_apple_uid_123',
            info: {
              email: 'test@appleid.com',
              first_name: 'Test',
              last_name: 'Apple',
              name: 'Test Apple'
            }
          })
        elsif provider == :google_oauth2
          OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
            provider: 'google_oauth2',
            uid: 'test_google_uid_456',
            info: {
              email: 'test@gmail.com',
              first_name: 'Test',
              last_name: 'Google',
              name: 'Test Google'
            }
          })
        end
      when :failure
        OmniAuth.config.mock_auth[provider] = :invalid_credentials
      end
    end
    
    # Helper method to clear OAuth mocks
    def clear_oauth_mocks
      OmniAuth.config.mock_auth.clear
    end
  end
end

module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
    
    # Skip CSRF verification in tests for easier integration testing
    setup do
      ActionController::Base.allow_forgery_protection = false
    end
    
    teardown do
      ActionController::Base.allow_forgery_protection = true
    end
  end
end