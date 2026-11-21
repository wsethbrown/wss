require "application_system_test_case"

# The password path on /auth branches on one email lookup. An unknown email
# must say plainly that no account uses it, not silently swap to a sign-up form.
class AuthPasswordPathTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: "known@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Known",
      last_name: "Member"
    )
  end

  test "unknown email says no account uses it and shows the sign-up fields" do
    visit auth_path
    fill_in "magic-link-email", with: "nobody@example.com"
    click_button "Use a password instead"

    notice = find("#password-notice", visible: true)
    assert_equal "status", notice[:role]
    assert_equal "polite", notice[:"aria-live"]
    assert_text "No account uses nobody@example.com yet."
    assert_text "Fill in the form below to create one. If you already have an account, check the address above for a typo."
    assert_no_text "Creating an account for"
    assert_selector "#password-signup", visible: true
    assert_field "user_first_name"
    assert_no_selector "#password-signin", visible: true
  end

  test "known email shows the password field and no notice" do
    visit auth_path
    fill_in "magic-link-email", with: @user.email
    click_button "Use a password instead"

    assert_selector "#password-signin", visible: true
    assert_field "signin-password"
    assert_no_text "No account uses"
    assert_no_selector "#password-notice", visible: true
    assert_no_selector "#password-signup", visible: true
  end

  test "editing the email updates the notice and hiding the section clears it" do
    visit auth_path
    fill_in "magic-link-email", with: "nobody@example.com"
    click_button "Use a password instead"
    assert_text "No account uses nobody@example.com yet."

    fill_in "magic-link-email", with: "other@example.com"
    assert_text "No account uses other@example.com yet."
    assert_no_text "nobody@example.com"

    fill_in "magic-link-email", with: @user.email
    assert_selector "#password-signin", visible: true
    assert_no_text "No account uses"

    fill_in "magic-link-email", with: "third@example.com"
    assert_text "No account uses third@example.com yet."
    click_button "Hide password sign-in"
    assert_no_selector "#password-notice", visible: true
    click_button "Use a password instead"
    assert_text "No account uses third@example.com yet."
  end
end
