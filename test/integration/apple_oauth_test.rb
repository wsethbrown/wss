require "test_helper"

class AppleOAuthTest < ActionDispatch::IntegrationTest
  def setup
    # Sign in with Apple is registered only when real APPLE_* credentials are present
    # (see config/initializers/devise.rb). Without them the omniauth-apple routes don't
    # exist, so these tests can't run — skip cleanly rather than error.
    skip "Apple Sign In not configured in this environment" unless Devise.omniauth_configs.key?(:apple)

    # Clear any existing OAuth mocks
    clear_oauth_mocks

    # Clean up any existing test emails
    Dir.glob("#{Rails.root}/tmp/mail/*").each { |file| File.delete(file) }

    # Ensure we start with a clean database state
    User.destroy_all
  end

  def teardown
    clear_oauth_mocks
  end

  test "Apple OAuth initiation redirects to Apple authorization" do
    # This test verifies that clicking the Apple OAuth button initiates the flow
    get auth_path
    assert_response :success

    # The page should contain the Apple OAuth button
    assert_select "a[href='#{user_apple_omniauth_authorize_path}']"

    # Clicking the Apple OAuth button should redirect to Apple (or callback in test mode)
    post user_apple_omniauth_authorize_path

    # In test mode, this should redirect to the callback
    assert_redirected_to user_apple_omniauth_callback_path
  end

  test "Apple OAuth callback creates new user and signs them in" do
    # Set up successful Apple OAuth mock
    setup_oauth_mock(:apple, :success)

    # Simulate the OAuth callback (this would normally come from Apple)
    post user_apple_omniauth_callback_path

    # Should redirect to account page after successful sign in
    assert_redirected_to account_path

    # User should be created in database
    user = User.find_by(email: "test@appleid.com")
    assert_not_nil user
    assert_equal "apple", user.provider
    assert_equal "test_apple_uid_123", user.uid
    assert_equal "Test", user.first_name
    assert_equal "Apple", user.last_name

    # User should be signed in
    follow_redirect!
    assert_response :success

    # Should show signed in state (Account and Sign Out links)
    assert_select "a[href='#{account_path}']", text: "Account"
    assert_select "a[href='#{destroy_user_session_path}']", text: "Sign Out"
  end

  test "Apple OAuth callback signs in existing user" do
    # Create an existing user with Apple OAuth credentials
    existing_user = User.create!(
      email: "test@appleid.com",
      password: "password",
      password_confirmation: "password",
      provider: "apple",
      uid: "test_apple_uid_123",
      first_name: "Test",
      last_name: "Apple"
    )

    # Set up Apple OAuth mock
    setup_oauth_mock(:apple, :success)

    # Simulate the OAuth callback
    post user_apple_omniauth_callback_path

    # Should redirect to account page
    assert_redirected_to account_path

    # Should not create a new user
    assert_equal 1, User.count

    # Should sign in the existing user
    follow_redirect!
    assert_response :success
  end

  test "Apple OAuth callback handles missing authentication data" do
    # Don't set up any mock (simulates missing omniauth.auth)
    OmniAuth.config.mock_auth[:apple] = nil

    # Simulate callback without authentication data
    post user_apple_omniauth_callback_path

    # Should redirect to sign in with error
    assert_redirected_to auth_path

    # Should show error message
    follow_redirect!
    assert_match /Authentication data not received/, response.body
  end

  test "Apple OAuth callback handles authentication failure" do
    # Set up failed OAuth mock
    setup_oauth_mock(:apple, :failure)

    # Simulate failed authentication callback
    post user_apple_omniauth_callback_path

    # Should redirect to OAuth failure handler
    assert_match %r{/users/auth/failure}, response.location

    # Follow the failure redirect
    follow_redirect!

    # Should eventually redirect to auth page with error
    assert_redirected_to auth_path

    follow_redirect!
    assert_match /Authentication failed/, response.body
  end

  test "Apple OAuth callback handles user creation errors" do
    # Set up mock with invalid email to trigger validation error
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new({
      provider: "apple",
      uid: "test_apple_uid_123",
      info: {
        email: "invalid-email", # Invalid email format
        first_name: "Test",
        last_name: "Apple"
      }
    })

    # Simulate callback with invalid user data
    post user_apple_omniauth_callback_path

    # Should redirect to auth page with error
    assert_redirected_to auth_path

    # Should not create user
    assert_equal 0, User.count

    follow_redirect!
    assert_match /Authentication failed/, response.body
  end

  test "Apple OAuth handles CSRF protection correctly" do
    # Set up successful Apple OAuth mock
    setup_oauth_mock(:apple, :success)

    # Make request without CSRF token (simulating potential CSRF attack)
    post user_apple_omniauth_callback_path, headers: { "X-CSRF-Token" => "invalid" }

    # Should still work because OAuth callbacks should skip CSRF
    assert_redirected_to account_path

    # User should be created
    user = User.find_by(email: "test@appleid.com")
    assert_not_nil user
  end

  test "Apple OAuth complete flow from auth page" do
    # Start at auth page
    get auth_path
    assert_response :success

    # Set up successful Apple OAuth mock
    setup_oauth_mock(:apple, :success)

    # Initiate OAuth flow
    post user_apple_omniauth_authorize_path
    assert_redirected_to user_apple_omniauth_callback_path

    # Complete OAuth callback
    post user_apple_omniauth_callback_path
    assert_redirected_to account_path

    # User should be created and signed in
    user = User.find_by(email: "test@appleid.com")
    assert_not_nil user
    assert_equal "apple", user.provider

    # Should be able to access account page
    follow_redirect!
    assert_response :success
  end

  test "Apple OAuth links to existing user with same email but different provider" do
    # Create user with same email but different provider
    existing_user = User.create!(
      email: "test@appleid.com",
      password: "password",
      password_confirmation: "password",
      provider: "google_oauth2",
      uid: "different_uid",
      first_name: "Existing",
      last_name: "User"
    )

    # Set up Apple OAuth mock with same email
    setup_oauth_mock(:apple, :success)

    # Simulate Apple OAuth callback
    post user_apple_omniauth_callback_path

    # Should successfully sign in and link to existing user
    assert_redirected_to account_path

    # Should still have only 1 user (account linking)
    assert_equal 1, User.count

    # User should now have Apple provider info
    existing_user.reload
    assert_equal "apple", existing_user.provider
    assert_equal "test_apple_uid_123", existing_user.uid
    assert_equal "test@appleid.com", existing_user.email

    # Should be signed in as this user
    follow_redirect!
    assert_response :success
  end
end
