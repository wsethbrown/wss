require "application_system_test_case"

class MagicLinksTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    )

    # Clear any existing emails
    mail_dir = Rails.root.join("tmp/mail")
    Dir.glob("#{mail_dir}/*").each { |file| File.delete(file) } if Dir.exist?(mail_dir)
  end

  # Where this test's lines start in the server log (see before_teardown).
  def before_setup
    super
    @log_path = Rails.root.join("log/test.log")
    @log_start = File.exist?(@log_path) ? File.size(@log_path) : 0
  end

  # On failure, print what the app logged about magic links during this test
  # (sent to an existing user or as a new sign-up; signed in or refused, and
  # why). Seen once in CI: the link sent to an existing user landed back on
  # /auth, and the output alone could not say which branch refused it. These
  # log lines never contain a token or an address.
  def before_teardown
    unless passed? || skipped?
      Rails.logger.flush if Rails.logger.respond_to?(:flush)
      lines = File.exist?(@log_path) ? File.open(@log_path) { |f| f.seek(@log_start); f.read }.to_s.lines : []
      lines = lines.grep(/Magic[- ]link|Started (GET|POST) "\/(auth|dashboard|magic_links)/)
                   .map { |l| l.gsub(%r{magic_links/[A-Za-z0-9_-]+}, "magic_links/[token]") }
      puts "\n--- Magic-link server log: #{name} ---", lines, "--- end ---"
    end
  ensure
    super
  end

  # Magic-link mail is sent with deliver_later and the test environment uses the
  # ActiveJob test adapter, so jobs enqueued by the app server must be performed
  # explicitly before the :file delivery writes the message to tmp/mail.
  def mail_file_for(email)
    Rails.root.join("tmp/mail", email)
  end

  def deliver_enqueued_mail
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob
    perform_enqueued_jobs
  end

  def magic_link_token_sent_to(email)
    path = mail_file_for(email)
    assert File.exist?(path), "Email to #{email} should have been delivered"
    content = Mail.read(path.to_s).then do |mail|
      parts = mail.multipart? ? mail.parts.map { |part| part.decoded } : [ mail.decoded ]
      parts.join("\n")
    end
    match = content.match(%r{magic_links/([A-Za-z0-9_-]+)})
    assert match, "Magic link should be found in email"
    [ content, match[1] ]
  end

  def teardown
    # Clean up emails after test
    mail_dir = Rails.root.join("tmp/mail")
    Dir.glob("#{mail_dir}/*").each { |file| File.delete(file) } if Dir.exist?(mail_dir)
  end

  test "magic link form submission for existing user" do
    visit auth_path

    assert_text "Join the Society"

    # The email form is visible immediately (no toggle)
    assert_selector "#magic-link-form", visible: true
    assert_field "magic-link-email"

    fill_in "magic-link-email", with: @user.email
    click_button "Send magic link"

    assert_current_path auth_path
    assert_text "Check your email for a magic link to sign in."

    deliver_enqueued_mail

    content, _token = magic_link_token_sent_to(@user.email)
    assert_includes content, "Sign in to Whiskey Share Society"
  end

  test "magic link form submission for new user" do
    new_email = "newuser@example.com"

    visit auth_path
    assert_selector "#magic-link-form", visible: true
    fill_in "magic-link-email", with: new_email
    click_button "Send magic link"

    # New and existing addresses get the same message (no account disclosure)
    assert_current_path auth_path
    assert_text "Check your email for a magic link to sign in."

    deliver_enqueued_mail

    # The registration email carries the link that creates the account
    content, _token = magic_link_token_sent_to(new_email)
    assert_includes content, "Create my account"
    assert_nil User.find_by(email: new_email), "No account is created until the link is used"
  end

  test "a new address's link asks before creating the account, then signs in" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new # pending sign-ups live in the cache
    new_email = "confirm.me@example.com"

    visit auth_path
    assert_selector "#magic-link-form", visible: true
    fill_in "magic-link-email", with: new_email
    click_button "Send magic link"
    assert_text "Check your email for a magic link to sign in."
    deliver_enqueued_mail
    _content, token = magic_link_token_sent_to(new_email)

    visit magic_link_path(token: token)
    assert_text "Welcome to the Society"
    assert_nil User.find_by(email: new_email), "opening the link creates nothing"

    click_button "Create my account"
    assert_current_path dashboard_path
    assert_text "You're signed in. Welcome back!"
    assert User.find_by(email: new_email)
  ensure
    Rails.cache = original_cache
  end

  test "magic link form is visible without any toggling" do
    visit auth_path

    assert_selector "#magic-link-form", visible: true
    assert_field "magic-link-email"
  end

  test "magic link actually works for signing in" do
    visit auth_path
    # Wait for the page (and its Stimulus/inline scripts) to settle before typing;
    # filling immediately after visit hit a detached node on CI.
    assert_selector "#magic-link-form", visible: true
    fill_in "magic-link-email", with: @user.email
    click_button "Send magic link"
    assert_text "Check your email for a magic link to sign in."

    deliver_enqueued_mail
    _content, token = magic_link_token_sent_to(@user.email)

    visit magic_link_path(token: token)

    # Signed in and on the dashboard: no page was waiting for this sign-in,
    # so it lands where every sign-in does by default (finding 4).
    assert_current_path dashboard_path
    assert_text "You're signed in. Welcome back!"
    assert_link "Sign out"
  end
end
