require "test_helper"

class GoogleOAuthTest < ActionDispatch::IntegrationTest
  def setup
    # Clear any existing OAuth mocks
    clear_oauth_mocks
    
    # Clean up any existing test emails. rm_f: parallel workers race on this
    # shared directory, and a file already deleted by a sibling is success.
    Dir.glob("#{Rails.root}/tmp/mail/*").each { |file| FileUtils.rm_f(file) }
    
    # Ensure we start with a clean database state
  end

  def teardown
    clear_oauth_mocks
  end

  test "Google OAuth initiation redirects to Google authorization" do
    # This test verifies that clicking the Google OAuth button initiates the flow
    get auth_path
    assert_response :success
    
    # The page should contain the Google OAuth button as a POST form
    # (omniauth-rails_csrf_protection requires POST initiation).
    assert_select "form[action='#{user_google_oauth2_omniauth_authorize_path}'] button", /Continue with Google/
    
    # Clicking the Google OAuth button should redirect to Google (or callback in test mode)
    post user_google_oauth2_omniauth_authorize_path
    
    # In test mode, this should redirect to the callback
    assert_redirected_to user_google_oauth2_omniauth_callback_path
  end

  test "Google OAuth callback creates new user and signs them in" do
    # Set up successful Google OAuth mock
    setup_oauth_mock(:google_oauth2, :success)
    
    # Simulate the OAuth callback (this would normally come from Google)
    post user_google_oauth2_omniauth_callback_path
    
    # Should redirect to account page after successful sign in
    assert_redirected_to account_path
    
    # User should be created in database
    user = User.find_by(email: 'test@gmail.com')
    assert_not_nil user
    assert_equal 'google_oauth2', user.provider
    assert_equal 'test_google_uid_456', user.uid
    assert_equal 'Test', user.first_name
    assert_equal 'Google', user.last_name
    
    # User should be signed in
    follow_redirect!
    assert_response :success
  end

  test "Google OAuth callback signs in existing user" do
    # Create an existing user with Google OAuth credentials
    existing_user = User.create!(
      email: 'test@gmail.com',
      password: 'password',
      password_confirmation: 'password',
      provider: 'google_oauth2',
      uid: 'test_google_uid_456',
      first_name: 'Test',
      last_name: 'Google'
    )
    
    # Set up Google OAuth mock
    setup_oauth_mock(:google_oauth2, :success)
    
    # Simulate the OAuth callback — must sign in the existing user,
    # not create a new one.
    assert_no_difference "User.count" do
      post user_google_oauth2_omniauth_callback_path
    end

    # Should redirect to account page
    assert_redirected_to account_path
    
    # Should sign in the existing user
    follow_redirect!
    assert_response :success
  end

  test "Google OAuth complete flow from auth page" do
    # Start at auth page
    get auth_path
    assert_response :success
    
    # Set up successful Google OAuth mock
    setup_oauth_mock(:google_oauth2, :success)
    
    # Initiate OAuth flow
    post user_google_oauth2_omniauth_authorize_path
    assert_redirected_to user_google_oauth2_omniauth_callback_path
    
    # Complete OAuth callback
    post user_google_oauth2_omniauth_callback_path
    assert_redirected_to account_path
    
    # User should be created and signed in
    user = User.find_by(email: 'test@gmail.com')
    assert_not_nil user
    assert_equal 'google_oauth2', user.provider
    
    # Should be able to access account page
    follow_redirect!
    assert_response :success
  end
end