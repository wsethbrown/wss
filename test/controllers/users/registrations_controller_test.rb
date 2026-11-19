require "test_helper"

# B4: self-service account deletion is disabled until a real deletion service
# exists (see docs/redesign/ACCOUNT_DELETION.md).
class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_test_user
    post user_session_path, params: { user: { email: @user.email, password: "password" } }
  end

  test "DELETE /users deletes nothing and redirects to contact" do
    assert_no_difference -> { User.count } do
      delete user_registration_path
    end
    assert_redirected_to contact_path
    assert_predicate flash[:notice], :present?
    assert User.exists?(@user.id)
  end

  test "DELETE /users leaves the user's data alone" do
    counts = -> { [ Society.count, SocietyMembership.count, CreditTransaction.count, Event.count ] }
    before = counts.call
    delete user_registration_path
    assert_equal before, counts.call
  end

  test "signed-out DELETE /users deletes nothing" do
    delete destroy_user_session_path
    assert_no_difference -> { User.count } do
      delete user_registration_path
    end
  end

  test "edit page no longer offers the cancel-account button" do
    get edit_user_registration_path
    assert_response :success
    assert_select "form[action=?][method=post] input[name=_method][value=delete]", user_registration_path, count: 0
    assert_includes response.body, contact_path
  end

  test "edit page shows the email read-only and points to the account page" do
    get edit_user_registration_path
    assert_response :success
    assert_select "input[name='user[email]']", count: 0
    assert_includes response.body, @user.email
    assert_select "a[href=?]", account_path(anchor: "account-details")
  end

  # B8 (S6): the email is the sign-in credential; it changes only through the
  # account page's confirm-from-the-new-mailbox flow, never here.
  test "the Devise account update cannot change the email" do
    put user_registration_path, params: { user: { email: "hijack@example.com", current_password: "password" } }
    assert_redirected_to account_path
    assert_equal "test@example.com", @user.reload.email
  end

  test "a Devise account update carrying the same email in another case still saves" do
    put user_registration_path, params: { user: { email: "TEST@example.com", first_name: "Renamed", current_password: "password" } }
    assert_equal "Renamed", @user.reload.first_name
    assert_equal "test@example.com", @user.email
  end
end
