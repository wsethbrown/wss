require "test_helper"

# B3: rate limits on the five abuse-prone entry points, plus sign-in hardening.
# The limiter is a no-op in the test environment (so the rest of the suite is
# unaffected); these tests switch it on with RateLimitStore.enable_for_test!.
class RateLimitsTest < ActionDispatch::IntegrationTest
  setup do
    RateLimitStore.enable_for_test!
    @user = User.create!(email: "Jon@Example.com", password: "password123", password_confirmation: "password123",
                         first_name: "Jon", last_name: "Doe")
  end

  teardown { RateLimitStore.disable_for_test! }

  test "password sign-in is limited per IP and sends 429 after the limit" do
    AuthController::SIGN_IN_LIMIT.times do
      post user_session_path, params: { user: { email: "x#{SecureRandom.hex(3)}@example.com", password: "nope" } }
      assert_response :unprocessable_entity
    end
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
    assert_rate_limited_redirect
    assert_not controller_signed_in?
  end

  test "password sign-in is limited per target email across IPs" do
    AuthController::SIGN_IN_EMAIL_LIMIT.times do |i|
      post user_session_path, params: { user: { email: @user.email, password: "wrong" } },
                              headers: { "REMOTE_ADDR" => "10.0.0.#{i + 1}" }
      assert_response :unprocessable_entity
    end
    post user_session_path, params: { user: { email: @user.email, password: "password123" } },
                            headers: { "REMOTE_ADDR" => "10.9.9.9" }
    assert_rate_limited_redirect
  end

  test "limits reset after the window" do
    AuthController::SIGN_IN_LIMIT.times { post user_session_path, params: { user: { email: "a@example.com", password: "x" } } }
    post user_session_path, params: { user: { email: "a@example.com", password: "x" } }
    assert_rate_limited_redirect
    travel AuthController::SIGN_IN_WINDOW + 1.second do
      post user_session_path, params: { user: { email: @user.email, password: "password123" } }
      assert_redirected_to dashboard_path
    end
  end

  test "mixed-case email signs in" do
    post user_session_path, params: { user: { email: "JON@EXAMPLE.COM", password: "password123" } }
    assert_redirected_to dashboard_path
  end

  test "sign-in without a user param is a 4xx, not a 500" do
    post user_session_path, params: {}
    assert_includes 400..499, response.status
  end

  test "failed sign-in does not log the attempted email" do
    io = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    post user_session_path, params: { user: { email: "secret-probe@example.com", password: "x" } }
    Rails.logger = old
    assert_not_includes io.string, "secret-probe@example.com"
    assert_match(/Failed password sign-in/, io.string)
  end

  test "an HTML post that is rate limited redirects back to the referring page" do
    AuthController::SIGN_IN_LIMIT.times { post user_session_path, params: { user: { email: "a@example.com", password: "x" } } }
    post user_session_path, params: { user: { email: "a@example.com", password: "x" } }, headers: { "HTTP_REFERER" => auth_url }
    assert_redirected_to auth_url
    assert_rate_limited_redirect
  end

  test "email_check is limited per IP" do
    AuthController::EMAIL_CHECK_LIMIT.times { post "/auth/email_check", params: { email: "a@example.com" }, as: :json }
    assert_response :success
    post "/auth/email_check", params: { email: "a@example.com" }, as: :json
    assert_response :too_many_requests
    assert JSON.parse(response.body)["error"].present?
  end

  test "magic link requests are limited per email and send no further email" do
    MagicLinksController::EMAIL_LIMIT.times { post magic_links_path, params: { email: @user.email } }
    assert_no_enqueued_jobs do
      post magic_links_path, params: { email: @user.email.upcase }
    end
    assert_rate_limited_redirect
    # A different address from the same IP is still fine.
    post magic_links_path, params: { email: "other@example.com" }
    assert_redirected_to auth_path
  end

  test "the per-email magic link limit also covers addresses with no account, across IPs" do
    unknown = "nobody.here@business.example"
    MagicLinksController::EMAIL_LIMIT.times do |i|
      post magic_links_path, params: { email: unknown }, headers: { "REMOTE_ADDR" => "10.1.0.#{i + 1}" }
      assert_redirected_to auth_path
    end
    assert_no_enqueued_jobs do
      post magic_links_path, params: { email: " #{unknown.upcase} " }, headers: { "REMOTE_ADDR" => "10.1.0.99" }
    end
    assert_rate_limited_redirect
    assert_nil User.find_by(email: unknown)
  end

  test "password sign-up is limited per IP and creates no further users" do
    Users::RegistrationsController::SIGN_UP_IP_LIMIT.times do |i|
      post user_registration_path, params: { user: { email: "signup#{i}@example.com", password: "short" } }
    end
    assert_no_difference -> { User.count } do
      post user_registration_path, params: { user: { email: "fresh.signup@example.com", first_name: "F", last_name: "S",
                                                     password: "password123", password_confirmation: "password123" } }
    end
    assert_rate_limited_redirect
  end

  test "password reset requests are limited per email and send no further email" do
    Users::PasswordsController::EMAIL_LIMIT.times do |i|
      post user_password_path, params: { user: { email: @user.email } }, headers: { "REMOTE_ADDR" => "10.2.0.#{i + 1}" }
    end
    # Devise sends the reset mail inline from this class method; it must not run.
    User.expects(:send_reset_password_instructions).never
    post user_password_path, params: { user: { email: @user.email } }, headers: { "REMOTE_ADDR" => "10.2.0.99" }
    assert_rate_limited_redirect
  end

  test "password reset requests are limited per IP" do
    Users::PasswordsController::IP_LIMIT.times { |i| post user_password_path, params: { user: { email: "r#{i}@example.com" } } }
    post user_password_path, params: { user: { email: @user.email } }
    assert_rate_limited_redirect
  end

  test "magic link requests are limited per IP" do
    MagicLinksController::IP_LIMIT.times { |i| post magic_links_path, params: { email: "u#{i}@example.com" } }
    assert_no_enqueued_jobs do
      post magic_links_path, params: { email: "fresh@example.com" }
    end
    assert_rate_limited_redirect
  end

  test "email change requests are limited per user" do
    sign_in @user
    AccountController::EMAIL_CHANGE_LIMIT.times do |i|
      patch "/account/change_email", params: { new_email: "new#{i}@example.com" }
      assert_response :redirect
    end
    assert_no_enqueued_jobs do
      patch "/account/change_email", params: { new_email: "one-more@example.com" }
    end
    assert_rate_limited_redirect
  end

  test "society invitations are limited per user" do
    owner = users(:john)
    society = Society.create!(name: "Rate Society", description: "x", creator: owner, is_private: false)
    sign_in owner
    SocietyInvitationsController::INVITE_LIMIT.times do
      post society_invitations_path, params: { society_id: society.id, email: "nobody@example.com" }
      assert_response :redirect
    end
    post society_invitations_path, params: { society_id: society.id, email: "nobody@example.com" }
    assert_rate_limited_redirect
  end

  private

  def assert_rate_limited_redirect
    assert_response :see_other
    assert_equal RateLimitedResponses::RATE_LIMITED_MESSAGE, flash[:alert]
  end

  def controller_signed_in?
    get dashboard_path
    !(response.redirect? && response.location =~ /sign_in|auth/)
  end
end
