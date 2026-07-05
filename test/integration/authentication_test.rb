require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user
  end

  test "user can sign in with email and password" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
  end

  test "user can sign out" do
    sign_in @user
    get dashboard_path

    delete destroy_user_session_path

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "user registration creates new account" do
    post user_registration_path, params: {
      user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "New",
        last_name: "User"
      }
    }

    assert_redirected_to dashboard_path
    assert User.exists?(email: "newuser@example.com")
  end

  test "google oauth button is present" do
    get auth_path

    assert_response :success
    # OmniAuth initiation must be POST (omniauth-rails_csrf_protection), so the
    # control is a button_to form, not an <a> link.
    assert_select "form[action*='/users/auth/google_oauth2'] button", /Continue with Google/
  end

  test "apple oauth button appears only when Apple Sign In is configured" do
    get auth_path
    assert_response :success

    if Devise.omniauth_configs.key?(:apple)
      assert_select "form[action*='/users/auth/apple']"
    else
      # Apple is gated on real credentials; when unconfigured the button is hidden
      # rather than linking to a broken/insecure endpoint.
      assert_select "form[action*='/users/auth/apple']", count: 0
    end
  end

  test "unauthenticated user is redirected when accessing dashboard" do
    get dashboard_path

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "authenticated user can access dashboard" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }
    follow_redirect!

    assert_response :success
    assert_select "h1", "Account"
    assert_select "h2", "Profile"
  end

  test "failed authentication shows error" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "wrongpassword"
      }
    }

    assert_response :unprocessable_entity
    assert_match /Invalid Email or password/, response.body
  end

  test "auth page shows correct navigation" do
    get auth_path

    assert_response :success
    assert_select "h2", "Join the Society"
    assert_select "button", "Sign Up"
    # OAuth controls are POST forms (CSRF-protected), not links. Apple only
    # renders when configured, so it is asserted in its own dedicated test.
    assert_select "form[action*='/users/auth/google_oauth2'] button", /Continue with Google/
  end

  test "dashboard shows user profile information" do
    post user_session_path, params: {
      user: {
        email: @user.email,
        password: "password"
      }
    }
    follow_redirect!

    assert_response :success
    assert_select "input[value=?]", @user.first_name
    assert_select "input[value=?]", @user.last_name
    # Email is display-only on the profile (changing it goes through the
    # separate re-verification flow), so it renders as text, not an input.
    assert_match @user.email, response.body
  end
end
