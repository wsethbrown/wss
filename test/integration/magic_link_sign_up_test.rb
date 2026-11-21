require "test_helper"

# A magic link requested for an address with no account must not create one.
# The pending sign-up lives server-side with the hashed token (Rails.cache,
# 15 minutes, single use) and the account is created only when a person
# confirms on the page the link opens. The GET alone changes nothing, so a
# corporate mail scanner that follows every link creates no account.
class MagicLinkSignUpTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  NEW_EMAIL = "stranger@business.example".freeze

  setup do
    # Pending sign-ups live in the cache; the test env defaults to :null_store.
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    clear_enqueued_jobs
  end

  teardown do
    Rails.cache = @original_cache
  end

  def enqueued_magic_token
    job = enqueued_jobs.reverse.find { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }
    ActiveJob::Arguments.deserialize(job["arguments"]).last[:args].last
  end

  def mail_jobs
    enqueued_jobs.select { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }
  end

  test "requesting a link for an unknown address creates no user and enqueues exactly one mail" do
    assert_no_difference -> { User.count } do
      post magic_links_path, params: { email: NEW_EMAIL }
    end
    assert_equal 1, mail_jobs.size
    assert_equal "magic_link_registration_email", ActiveJob::Arguments.deserialize(mail_jobs.first["arguments"])[1]
    assert_nil User.find_by(email: NEW_EMAIL)
  end

  test "opening the link shows a confirmation and still creates no user" do
    post magic_links_path, params: { email: NEW_EMAIL }
    raw = enqueued_magic_token
    reset!

    assert_no_difference -> { User.count } do
      get magic_link_path(token: raw)
    end
    assert_response :success
    assert_select "form[action='#{confirm_magic_link_path}'][method='post']" do
      assert_select "input[type=hidden][name=token]", 1
      assert_select "button", text: "Create my account"
    end
    assert_nil session["warden.user.user.key"], "nobody is signed in by the GET"

    # A second GET (a scanner, then the person) still works: nothing was used up.
    get magic_link_path(token: raw)
    assert_response :success
  end

  test "confirming creates the user once and signs them in" do
    post magic_links_path, params: { email: NEW_EMAIL }
    raw = enqueued_magic_token
    reset!

    get magic_link_path(token: raw)
    assert_difference -> { User.count }, 1 do
      post confirm_magic_link_path, params: { token: raw }
    end
    user = User.find_by!(email: NEW_EMAIL)
    assert_not user.password_set_manually
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
    assert_equal user.id, session["warden.user.user.key"]&.first&.first
  end

  test "confirming twice fails the second time" do
    post magic_links_path, params: { email: NEW_EMAIL }
    raw = enqueued_magic_token
    reset!

    post confirm_magic_link_path, params: { token: raw }
    assert_redirected_to dashboard_path
    reset!

    assert_no_difference -> { User.count } do
      post confirm_magic_link_path, params: { token: raw }
    end
    assert_redirected_to auth_path
    assert_match(/invalid or has expired/i, flash[:alert])

    get magic_link_path(token: raw)
    assert_redirected_to auth_path, "a used sign-up link no longer shows the confirmation"
  end

  test "an expired pending sign-up creates nothing" do
    post magic_links_path, params: { email: NEW_EMAIL }
    raw = enqueued_magic_token
    reset!

    travel Auth::MagicLinkService::EXPIRY + 1.minute do
      get magic_link_path(token: raw)
      assert_redirected_to auth_path
      assert_no_difference -> { User.count } do
        post confirm_magic_link_path, params: { token: raw }
      end
      assert_redirected_to auth_path
    end
  end

  test "a bogus confirmation token creates nothing" do
    assert_no_difference -> { User.count } do
      post confirm_magic_link_path, params: { token: "made-up" }
      post confirm_magic_link_path
    end
    assert_redirected_to auth_path
  end

  test "the response for known and unknown addresses is indistinguishable" do
    known = users(:john)

    post magic_links_path, params: { email: known.email }
    known_status, known_location, known_flash = response.status, response.location, flash.to_hash
    reset!

    post magic_links_path, params: { email: NEW_EMAIL }
    assert_equal known_status, response.status
    assert_equal known_location, response.location
    assert_equal known_flash, flash.to_hash
  end

  test "an existing account's link still signs in on the GET, as before" do
    user = users(:john)
    post magic_links_path, params: { email: user.email }
    raw = enqueued_magic_token
    reset!

    get magic_link_path(token: raw)
    assert_redirected_to dashboard_path
    assert_match(/signed in/i, flash[:notice])
    assert_nil user.reload.magic_link_token
  end

  test "the pending sign-up carries the return path to after confirmation" do
    target = society_path(societies(:single_malt))
    post magic_links_path, params: { email: NEW_EMAIL, return_to: target }
    raw = enqueued_magic_token
    reset!

    post confirm_magic_link_path, params: { token: raw }
    assert_redirected_to target
  end
end
