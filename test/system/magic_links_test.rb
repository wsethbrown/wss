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

  test "magic link form is visible without any toggling" do
    visit auth_path

    assert_selector "#magic-link-form", visible: true
    assert_field "magic-link-email"
  end

  test "magic link actually works for signing in" do
    visit auth_path
    fill_in "magic-link-email", with: @user.email
    click_button "Send magic link"
    assert_text "Check your email for a magic link to sign in."

    deliver_enqueued_mail
    _content, token = magic_link_token_sent_to(@user.email)

    visit magic_link_path(token: token)

    # Redirected to the account page and signed in
    assert_current_path account_path
    assert_text "You're signed in. Welcome back!"
    assert_link "Sign out"
  end
end
