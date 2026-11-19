require "test_helper"

# B2 / S1: an admin email edit is an account takeover vector (magic links make
# the mailbox the credential). Only full admins may change an email, never on
# another admin's record, and an allowed change kills every outstanding
# sign-in credential tied to the old address.
class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  def capture_log
    io = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old
  end

  test "a limited admin cannot change a member's email, and the refusal is logged" do
    sign_in users(:limited_admin)
    log = capture_log do
      patch admin_user_path(users(:john)), params: { user: { email: "attacker@example.com" } }
    end
    assert_equal "john@example.com", users(:john).reload.email
    assert_redirected_to edit_admin_user_path(users(:john))
    assert_match(/Admin #{users(:limited_admin).id} refused email change on user #{users(:john).id}/, log)
    assert_not_includes log, "attacker@example.com"
  end

  test "a limited admin cannot change a full admin's email" do
    sign_in users(:limited_admin)
    patch admin_user_path(users(:admin)), params: { user: { email: "attacker@example.com" } }
    assert_equal "admin@whiskeysharesociety.com", users(:admin).reload.email
  end

  test "a limited admin can still edit names and bio" do
    sign_in users(:limited_admin)
    patch admin_user_path(users(:john)), params: { user: { first_name: "Johnny", email: "john@example.com" } }
    assert_redirected_to admin_user_path(users(:john))
    assert_equal "Johnny", users(:john).reload.first_name
  end

  test "a full admin cannot change another admin's email" do
    sign_in users(:admin)
    patch admin_user_path(users(:limited_admin)), params: { user: { email: "attacker@example.com" } }
    assert_equal "limited-admin@whiskeysharesociety.com", users(:limited_admin).reload.email
  end

  test "email comparison ignores case, so resubmitting the same address is not a change" do
    sign_in users(:limited_admin)
    patch admin_user_path(users(:john)), params: { user: { email: "JOHN@example.com", bio: "Hi" } }
    assert_redirected_to admin_user_path(users(:john))
    assert_equal "Hi", users(:john).reload.bio
  end

  test "a full admin can change a member's email; old sign-in credentials stop working" do
    john = users(:john)
    raw_magic = "magic-#{SecureRandom.hex(8)}"
    raw_invite = "invite-#{SecureRandom.hex(8)}"
    john.update_columns(
      magic_link_token: Auth::MagicLinkService.digest(raw_magic), magic_link_sent_at: Time.current,
      invitation_token_digest: Auth::MagicLinkService.digest(raw_invite), invitation_sent_at: Time.current,
      remember_created_at: 1.hour.ago, reset_password_token: "digest-x", reset_password_sent_at: Time.current
    )

    sign_in users(:admin)
    log = capture_log do
      patch admin_user_path(john), params: { user: { email: "john.new@example.com" } }
    end
    assert_redirected_to admin_user_path(john)

    john.reload
    assert_equal "john.new@example.com", john.email
    assert_nil john.magic_link_token
    assert_nil john.invitation_token_digest
    assert_nil john.remember_created_at
    assert_nil john.reset_password_token
    assert_nil Auth::MagicLinkService.consume(raw_magic), "old magic link must not sign in"
    assert_nil Auth::InvitationService.consume(raw_invite), "old invitation must not sign in"

    assert_match(/Admin #{users(:admin).id} updated user #{john.id}: email/, log)
    assert_not_includes log, raw_magic
  end

  test "profile edits are logged with field names" do
    sign_in users(:admin)
    log = capture_log do
      patch admin_user_path(users(:john)), params: { user: { first_name: "Jonathan" } }
    end
    assert_match(/Admin #{users(:admin).id} updated user #{users(:john).id}: first_name/, log)
  end

  test "role changes are logged" do
    sign_in users(:admin)
    log = capture_log do
      patch update_role_admin_user_path(users(:john)), params: { admin_role: "limited" }
    end
    assert_match(/Admin #{users(:admin).id} changed role of user #{users(:john).id} from none to limited/, log)
  end

  test "the edit form shows the email field only when the editor may change it" do
    sign_in users(:admin)
    get edit_admin_user_path(users(:john))
    assert_select "input[name='user[email]']", 1
    get edit_admin_user_path(users(:limited_admin))
    assert_select "input[name='user[email]']", 0

    sign_in users(:limited_admin)
    get edit_admin_user_path(users(:john))
    assert_select "input[name='user[email]']", 0
  end
end
