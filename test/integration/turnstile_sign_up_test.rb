require "test_helper"

# Cloudflare Turnstile on the two public sign-up surfaces: the magic-link
# request and password registration. Off (and invisible) unless both
# TURNSTILE_* keys are set; password sign-in for existing accounts is not
# gated (rate limits cover it).
class TurnstileSignUpTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  NEW_EMAIL = "turnstile.newcomer@example.com".freeze

  setup do
    @saved = ENV.to_h.slice("TURNSTILE_SITE_KEY", "TURNSTILE_SECRET_KEY")
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY].each { |k| ENV.delete(k) }
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    clear_enqueued_jobs
  end

  teardown do
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY].each { |k| @saved.key?(k) ? ENV[k] = @saved[k] : ENV.delete(k) }
    Rails.cache = @original_cache
  end

  def turn_on!
    ENV["TURNSTILE_SITE_KEY"] = "site-key-test"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key-test"
  end

  def registration_params
    { user: { email: NEW_EMAIL, first_name: "New", last_name: "Person",
              password: "password123", password_confirmation: "password123" },
      "cf-turnstile-response" => "token-from-widget" }
  end

  def mail_jobs = enqueued_jobs.select { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }

  test "keys unset: no widget, no script, and both forms work as today" do
    Turnstile.expects(:post_siteverify).never

    get auth_path
    assert_select ".cf-turnstile", 0
    assert_no_match(/challenges\.cloudflare\.com/, response.body)
    get new_user_registration_path
    assert_select ".cf-turnstile", 0

    post magic_links_path, params: { email: NEW_EMAIL }
    assert_redirected_to auth_path
    assert_equal 1, mail_jobs.size

    assert_difference -> { User.count }, 1 do
      post user_registration_path, params: registration_params.except("cf-turnstile-response")
    end
  end

  test "keys set: the widget renders in the magic-link and both sign-up forms, not in password sign-in" do
    turn_on!
    get auth_path
    assert_select "#magic-link-form form .cf-turnstile[data-sitekey='site-key-test'][data-controller='turnstile']", 1
    assert_select "#password-signup form .cf-turnstile[data-sitekey='site-key-test']", 1
    assert_select "#password-signin .cf-turnstile", 0

    get new_user_registration_path
    assert_select "form[action='#{user_registration_path}'] .cf-turnstile[data-sitekey='site-key-test']", 1
  end

  test "keys set, verification fails: the magic-link request sends no mail and creates nothing" do
    turn_on!
    Turnstile.stubs(:verify).returns(Turnstile::Result.new(status: :rejected, error_codes: [ "invalid-input-response" ]))

    assert_no_difference -> { User.count } do
      post magic_links_path, params: { email: NEW_EMAIL, "cf-turnstile-response" => "bad" }
    end
    assert_empty mail_jobs
    assert_redirected_to auth_path
    assert_equal TurnstileProtection::REFUSED_MESSAGE, flash[:alert]
    assert_not Auth::MagicLinkService.pending_sign_up?("anything")
  end

  test "keys set, no token at all: refused" do
    turn_on!
    Turnstile.expects(:post_siteverify).never
    post magic_links_path, params: { email: users(:john).email }
    assert_empty mail_jobs
    assert_nil users(:john).reload.magic_link_token
    assert_equal TurnstileProtection::REFUSED_MESSAGE, flash[:alert]
  end

  test "keys set, verification fails: registration creates no user" do
    turn_on!
    Turnstile.stubs(:verify).returns(Turnstile::Result.new(status: :rejected, error_codes: []))
    assert_no_difference -> { User.count } do
      post user_registration_path, params: registration_params
    end
    assert_redirected_to auth_path
    assert_equal TurnstileProtection::REFUSED_MESSAGE, flash[:alert]
  end

  test "keys set, Cloudflare unreachable: sign-up fails closed with its own message" do
    turn_on!
    Turnstile.stubs(:post_siteverify).raises(Net::OpenTimeout)
    assert_no_difference -> { User.count } do
      post user_registration_path, params: registration_params
      post magic_links_path, params: { email: NEW_EMAIL, "cf-turnstile-response" => "tok" }
    end
    assert_empty mail_jobs
    assert_equal TurnstileProtection::UNAVAILABLE_MESSAGE, flash[:alert]
  end

  test "keys set, verification passes: both work" do
    turn_on!
    Turnstile.stubs(:verify).returns(Turnstile::Result.new(status: :passed, error_codes: []))

    post magic_links_path, params: { email: NEW_EMAIL, "cf-turnstile-response" => "ok" }
    assert_redirected_to auth_path
    assert_match(/magic link/i, flash[:notice])
    assert_equal 1, mail_jobs.size

    assert_difference -> { User.count }, 1 do
      post user_registration_path, params: registration_params
    end
    assert User.find_by(email: NEW_EMAIL).password_set_manually
  end

  test "keys set: password sign-in for an existing account is not gated" do
    turn_on!
    Turnstile.expects(:verify).never
    post user_session_path, params: { user: { email: users(:seth).email, password: "password" } }
    assert_redirected_to dashboard_path
  end

  test "keys set: the response is the same for known and unknown addresses when the check passes" do
    turn_on!
    Turnstile.stubs(:verify).returns(Turnstile::Result.new(status: :passed, error_codes: []))
    post magic_links_path, params: { email: users(:john).email, "cf-turnstile-response" => "ok" }
    known = [ response.status, response.location, flash.to_hash ]
    reset!
    post magic_links_path, params: { email: NEW_EMAIL, "cf-turnstile-response" => "ok" }
    assert_equal known, [ response.status, response.location, flash.to_hash ]
  end
end
