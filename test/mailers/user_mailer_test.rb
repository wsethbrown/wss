require "test_helper"

# B8 (S6): the confirm link only ever goes to the new address.
class UserMailerTest < ActionMailer::TestCase
  setup { @user = users(:one) }

  test "email_change_confirmation goes to the new address with the link" do
    mail = UserMailer.email_change_confirmation(@user, "new.box@example.com", "rawtoken123")
    assert_equal [ "new.box@example.com" ], mail.to
    assert_includes mail.html_part.body.to_s, "/account/verify_email/rawtoken123"
    assert_includes mail.text_part.body.to_s, "/account/verify_email/rawtoken123"
  end

  test "email_change_notice goes to the current address without any link to confirm" do
    mail = UserMailer.email_change_notice(@user, "new.box@example.com")
    assert_equal [ @user.email ], mail.to
    assert_includes mail.text_part.body.to_s, "new.box@example.com"
    refute_includes mail.html_part.body.to_s, "verify_email"
    refute_includes mail.text_part.body.to_s, "verify_email"
  end

  test "the old-address verification mail no longer exists" do
    refute UserMailer.action_methods.include?("email_change_verification")
  end
end
