require "test_helper"

# Role promotion from the admin Users page. Only full admins may change roles,
# nobody may change their own, and the value is whitelisted against the enum.
class Admin::UserRolesTest < ActionDispatch::IntegrationTest
  test "a full admin can promote a user to limited admin" do
    sign_in users(:admin)
    patch update_role_admin_user_path(users(:john)), params: { admin_role: "limited" }
    assert_redirected_to admin_user_path(users(:john))
    assert_equal "limited", users(:john).reload.admin_role
  end

  test "a full admin can demote an admin back to regular user" do
    sign_in users(:admin)
    patch update_role_admin_user_path(users(:limited_admin)), params: { admin_role: "none" }
    assert_equal "none", users(:limited_admin).reload.admin_role
  end

  test "a limited admin cannot change anyone's role" do
    sign_in users(:limited_admin)
    patch update_role_admin_user_path(users(:john)), params: { admin_role: "full" }
    assert_equal "none", users(:john).reload.admin_role
  end

  test "an admin cannot change their own role" do
    sign_in users(:admin)
    patch update_role_admin_user_path(users(:admin)), params: { admin_role: "none" }
    assert_equal "full", users(:admin).reload.admin_role
  end

  test "unknown role values are rejected" do
    sign_in users(:admin)
    patch update_role_admin_user_path(users(:john)), params: { admin_role: "superadmin" }
    assert_equal "none", users(:john).reload.admin_role
  end

  test "admin_role cannot ride the general user update (mass assignment)" do
    sign_in users(:admin)
    patch admin_user_path(users(:john)), params: { user: { first_name: "John", admin_role: "full" } }
    assert_equal "none", users(:john).reload.admin_role
  end

  test "the role form shows for a full admin viewing someone else" do
    sign_in users(:admin)
    get admin_user_path(users(:john))
    assert_select "form[action=?]", update_role_admin_user_path(users(:john))
  end

  test "the role form is hidden from limited admins and on your own page" do
    sign_in users(:limited_admin)
    get admin_user_path(users(:john))
    assert_select "form[action=?]", update_role_admin_user_path(users(:john)), count: 0

    sign_in users(:admin)
    get admin_user_path(users(:admin))
    assert_select "form[action=?]", update_role_admin_user_path(users(:admin)), count: 0
  end
end
