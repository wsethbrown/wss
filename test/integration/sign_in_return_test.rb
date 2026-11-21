require "test_helper"

# Sign-in returns people to the page that sent them to sign in, by every path
# (password, magic link, OAuth, admin invitation), and otherwise to the
# dashboard. Only same-site paths are ever followed.
class SignInReturnTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = users(:seth)
    @society = societies(:single_malt)
    @target = society_path(@society)
  end

  def password_sign_in(user = @user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end

  # The raw token is a mail-job argument; read it from the enqueued job.
  def enqueued_magic_token
    job = enqueued_jobs.reverse.find { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }
    args = ActiveJob::Arguments.deserialize(job["arguments"])
    args.last[:args].last
  end

  test "password sign-in returns to the page named in return_to" do
    get auth_path(return_to: @target)
    password_sign_in
    assert_redirected_to @target
  end

  test "password sign-in with no return path goes to the dashboard" do
    get auth_path
    password_sign_in
    assert_redirected_to dashboard_path
  end

  test "an external return_to is ignored" do
    [ "https://evil.example/phish", "//evil.example/phish", "/\\evil.example" ].each do |bad|
      reset!
      get auth_path(return_to: bad)
      password_sign_in
      assert_redirected_to dashboard_path, "#{bad} must not be followed"
    end
  end

  test "a page that requires sign-in is returned to after password sign-in" do
    get new_society_path
    assert_redirected_to new_user_session_path
    password_sign_in
    assert_redirected_to new_society_path
  end

  test "a magic link opened in another browser returns to the page it was requested from" do
    get auth_path(return_to: @target)
    post magic_links_path, params: { email: @user.email, return_to: @target }
    raw = enqueued_magic_token

    reset! # a different browser: no session
    get magic_link_path(token: raw)
    assert_redirected_to @target
    assert_nil @user.reload.magic_link_return_to, "the stored path is consumed with the token"
  end

  test "a magic link for a brand-new account carries the return path too" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new # new-account tokens live in the cache
    post magic_links_path, params: { email: "brand.new@example.com", return_to: @target }
    raw = enqueued_magic_token
    reset!
    get magic_link_path(token: raw)
    assert_response :success # a new account confirms first; the GET creates nothing
    post confirm_magic_link_path, params: { token: raw }
    assert_redirected_to @target
  ensure
    Rails.cache = original_cache
  end

  test "a magic link with an external return path goes to the dashboard" do
    post magic_links_path, params: { email: @user.email, return_to: "https://evil.example" }
    raw = enqueued_magic_token
    reset!
    get magic_link_path(token: raw)
    assert_redirected_to dashboard_path
  end

  test "a magic link requested without a return path goes to the dashboard" do
    post magic_links_path, params: { email: @user.email }
    raw = enqueued_magic_token
    reset!
    get magic_link_path(token: raw)
    assert_redirected_to dashboard_path
  end

  test "Google sign-in returns to the stored page" do
    setup_oauth_mock(:google_oauth2, :success)
    get auth_path(return_to: @target)
    post user_google_oauth2_omniauth_callback_path
    assert_redirected_to @target
  ensure
    clear_oauth_mocks
  end

  test "Google sign-in with no return path goes to the dashboard" do
    setup_oauth_mock(:google_oauth2, :success)
    post user_google_oauth2_omniauth_callback_path
    assert_redirected_to dashboard_path
  ensure
    clear_oauth_mocks
  end

  test "the invitation welcome page continues to the stored page" do
    raw = Auth::InvitationService.invite!(
      email: "invitee.return@example.com", first_name: "In", last_name: "Vitee", invited_by: users(:admin)
    ).raw_token
    get auth_path(return_to: @target)
    get invitation_path(token: raw)
    assert_response :success
    assert_select "a[href='#{@target}']", text: "Continue"
  end

  test "the invitation welcome page goes to the dashboard when nothing is stored" do
    raw = Auth::InvitationService.invite!(
      email: "invitee.plain@example.com", first_name: "In", last_name: "Vitee", invited_by: users(:admin)
    ).raw_token
    get invitation_path(token: raw)
    assert_select "a[href='#{dashboard_path}']", text: "Go to your dashboard"
  end

  test "the auth page carries the return path into the magic-link form" do
    get auth_path(return_to: @target)
    assert_select "#magic-link-form input[name='return_to'][value='#{@target}']"
  end

  test "Sign in to RSVP and Sign in to join carry the current page" do
    event = events(:mystery_flight)
    get society_event_path(event.society, event)
    assert_select "a[href='#{auth_path(return_to: society_event_path(event.society, event))}']", text: "Sign in to RSVP"

    get society_path(@society)
    assert_select "a[href='#{auth_path(return_to: society_path(@society))}']", text: "Sign in to join"
  end
end
