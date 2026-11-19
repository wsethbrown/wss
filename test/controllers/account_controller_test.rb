require "test_helper"

# B8 (S6): an email change is confirmed from the NEW mailbox, the old address
# only gets a notice, the token is stored as a digest, and addresses compare
# case-insensitively.
class AccountControllerEmailChangeTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @user = users(:one)
    sign_in @user
    # Test env delivers to files; capture in memory for these assertions.
    @delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ActionMailer::Base.delivery_method = @delivery_method
  end

  def request_change(new_email)
    perform_enqueued_jobs do
      patch account_change_email_path, params: { new_email: new_email }
    end
  end

  def mail_to(address)
    ActionMailer::Base.deliveries.find { |m| m.to.include?(address) }
  end

  def raw_token_from(mail)
    body = mail.html_part ? mail.html_part.body.to_s : mail.body.to_s
    body[%r{/account/verify_email/([^"\s<]+)}, 1]
  end

  test "the confirmation goes to the new address and a notice to the old one" do
    request_change("fresh.address@example.com")
    assert_redirected_to account_path

    confirmation = mail_to("fresh.address@example.com")
    notice = mail_to(@user.email)
    assert confirmation, "no confirmation sent to the new address"
    assert notice, "no notice sent to the old address"
    assert raw_token_from(confirmation).present?
    assert_nil raw_token_from(notice), "the old address must not receive the confirm link"
    refute_includes notice.text_part.body.to_s, "/account/verify_email/"
  end

  test "the old address alone cannot complete the change" do
    request_change("fresh.address@example.com")
    notice = mail_to(@user.email)
    # Nothing in the old mailbox carries a working link...
    assert_nil raw_token_from(notice)
    # ...and the stored value (all a database reader would see) does not work either.
    stored = @user.reload.email_change_token
    get verify_email_change_path(token: stored)
    assert_equal "one@example.com", @user.reload.email
  end

  test "the token is not stored in clear and the new-address link completes the change" do
    request_change("fresh.address@example.com")
    raw = raw_token_from(mail_to("fresh.address@example.com"))
    @user.reload
    refute_equal raw, @user.email_change_token
    assert_equal Auth::EmailChangeService.digest(raw), @user.email_change_token

    get verify_email_change_path(token: raw)
    assert_redirected_to auth_path
    @user.reload
    assert_equal "fresh.address@example.com", @user.email
    assert_nil @user.email_change_token
    assert_nil @user.unconfirmed_email
  end

  test "completing the change revokes the old address's magic link" do
    request_change("fresh.address@example.com")
    raw = raw_token_from(mail_to("fresh.address@example.com"))
    magic_raw = "old-mailbox-magic-link"
    @user.update_columns(magic_link_token: Auth::MagicLinkService.digest(magic_raw), magic_link_sent_at: Time.current)

    get verify_email_change_path(token: raw)
    assert_nil Auth::MagicLinkService.consume(magic_raw)
  end

  test "an expired link changes nothing" do
    request_change("fresh.address@example.com")
    raw = raw_token_from(mail_to("fresh.address@example.com"))
    @user.update_columns(email_change_token_expires_at: 1.minute.ago)
    get verify_email_change_path(token: raw)
    assert_equal "one@example.com", @user.reload.email
  end

  test "the current address in another case is not a change" do
    assert_no_emails { request_change("ONE@Example.com") }
    assert_nil @user.reload.unconfirmed_email
    assert_match "must be different", flash[:alert]
  end

  test "another account's address in another case is refused" do
    assert_no_emails { request_change("JANE@EXAMPLE.COM") }
    assert_nil @user.reload.unconfirmed_email
    assert_match "already in use", flash[:alert]
  end

  test "the new address is stored normalised" do
    request_change("  Fresh.Address@Example.COM ")
    assert_equal "fresh.address@example.com", @user.reload.unconfirmed_email
  end

  test "an address taken after the request does not 500 and changes nothing" do
    request_change("fresh.address@example.com")
    raw = raw_token_from(mail_to("fresh.address@example.com"))
    create_test_user(email: "Fresh.Address@example.com")
    get verify_email_change_path(token: raw)
    assert_redirected_to account_path
    assert_equal "one@example.com", @user.reload.email
    assert_nil @user.email_change_token
  end
end
