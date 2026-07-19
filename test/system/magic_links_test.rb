require "application_system_test_case"

class MagicLinksTest < ApplicationSystemTestCase
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

  def teardown
    # Clean up emails after test
    mail_dir = Rails.root.join("tmp/mail")
    Dir.glob("#{mail_dir}/*").each { |file| File.delete(file) } if Dir.exist?(mail_dir)
  end

  test "magic link form submission for existing user" do
    visit auth_path

    # Verify the initial state
    assert_text "Join the Society"

    # The email form is visible immediately (no toggle since the horizontal
    # auth layout, July 2026, the whole point is zero clicks to type an email)
    assert_selector "#magic-link-form", visible: true
    assert_field "Email address"

    # Fill and submit the form
    fill_in "Email address", with: @user.email

    # Check email count before submission
    initial_count = Dir.glob(Rails.root.join("tmp/mail/*")).count

    click_button "Send magic link"

    # Check if we were redirected
    assert_current_path auth_path
    assert_text "Check your email for a magic link to sign in!"

    # Check if email was generated
    final_count = Dir.glob(Rails.root.join("tmp/mail/*")).count
    assert_equal initial_count + 1, final_count, "Email should have been generated"

    # Verify email content
    if final_count > initial_count
      latest_email_file = Dir.glob(Rails.root.join("tmp/mail/*")).max_by { |f| File.mtime(f) }
      email_content = File.read(latest_email_file)
      assert_includes email_content, "magic_links/"
      assert_includes email_content, @user.email
    end
  end

  test "magic link form submission for new user" do
    new_email = "newuser@example.com"

    visit auth_path

    # Fill and submit the always-visible form
    fill_in "Email address", with: new_email

    # Check email count before submission
    initial_count = Dir.glob(Rails.root.join("tmp/mail/*")).count

    click_button "Send magic link"

    # Check if we were redirected
    assert_current_path auth_path
    assert_text "Check your email for a magic link to create your account!"

    # Check if email was generated
    final_count = Dir.glob(Rails.root.join("tmp/mail/*")).count
    assert_equal initial_count + 1, final_count, "Email should have been generated"
  end

  test "magic link form is visible without any toggling" do
    visit auth_path

    assert_selector "#magic-link-form", visible: true
    assert_field "Email address"
  end

  test "magic link actually works for signing in" do
    # First, create a magic link
    visit auth_path
    fill_in "Email address", with: @user.email
    click_button "Send magic link"

    # Extract the magic link from the email
    email_files = Dir.glob(Rails.root.join("tmp/mail/*"))
    assert email_files.any?, "Email should have been generated"

    latest_email = File.read(email_files.max_by { |f| File.mtime(f) })
    magic_link_match = latest_email.match(/magic_links\/([A-Za-z0-9_-]+)/)
    assert magic_link_match, "Magic link should be found in email"

    token = magic_link_match[1]

    # Visit the magic link
    visit magic_link_path(token: token)

    # Should be redirected to account page and signed in
    assert_current_path account_path
    assert_text "Successfully signed in with magic link!"

    # Verify user is actually signed in by checking for sign out link
    assert_link "Sign Out"
  end
end
