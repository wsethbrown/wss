require "test_helper"

class AccountNavigationTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Test',
      last_name: 'User'
    )
  end
  
  def sign_in_user
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: 'password123'
      }
    }
  end

  test "account page loads successfully" do
    sign_in_user
    get account_path
    
    assert_response :success
    assert_select 'h1', text: 'Account'
    
    # Check all navigation tabs are present
    assert_select '[data-tab="profile"]', text: /Profile/
    assert_select '[data-tab="account-details"]', text: /Account Details/
    assert_select '[data-tab="presentations"]', text: /My Presentations/
    assert_select '[data-tab="subscription"]', text: /Subscription/
    assert_select '[data-tab="billing"]', text: /Billing/
    assert_select '[data-tab="societies"]', text: /My Societies/
  end

  test "account page contains all tab content sections" do
    sign_in_user
    get account_path
    
    assert_response :success
    
    # Check all content sections exist
    assert_select '#profile-content'
    assert_select '#account-details-content'
    assert_select '#presentations-content'
    assert_select '#subscription-content'
    assert_select '#billing-content'
    assert_select '#societies-content'
  end

  test "profile tab has active styling by default" do
    sign_in_user
    get account_path
    
    assert_response :success
    
    # Profile tab should have active classes (brand "whiskey" accent)
    assert_select '[data-tab="profile"].text-whiskey-600'
    assert_select '[data-tab="profile"].bg-whiskey-50'
  end

  test "account details section contains expected content" do
    sign_in_user
    get account_path
    
    assert_response :success
    
    # Check account details content
    assert_select '#account-details-content', text: /Account Details/
    assert_select '#account-details-content', text: /Email Address/
    assert_select '#account-details-content', text: /Password & Security/
    # Substring match: the container holds much more text than just the email.
    assert_select '#account-details-content', text: /#{Regexp.escape(@user.email)}/
  end
end