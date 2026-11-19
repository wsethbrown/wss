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
end
