require "test_helper"

# End-to-end: admin sends an invitation; the recipient's claim link signs
# them in and lands on the welcome page; bad links fail safely.
class InvitationsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
  end

  test "an admin can invite a new member" do
    sign_in @admin
    assert_difference "User.count", 1 do
      post admin_invitations_path, params: {
        invitation: { first_name: "Nat", last_name: "McCarty", email: "nat.invite@example.com" }
      }
    end
    user = User.find_by(email: "nat.invite@example.com")
    assert_redirected_to admin_user_path(user)
    assert_equal @admin, user.invited_by
  end

  test "a duplicate email re-renders the form with an error" do
    sign_in @admin
    assert_no_difference "User.count" do
      post admin_invitations_path, params: {
        invitation: { first_name: "X", last_name: "Y", email: @admin.email }
      }
    end
    assert_response :unprocessable_entity
  end

  test "non-admins cannot invite" do
    sign_in users(:jane)
    post admin_invitations_path, params: {
      invitation: { first_name: "X", last_name: "Y", email: "sneaky@example.com" }
    }
    assert_response :redirect
    assert_nil User.find_by(email: "sneaky@example.com")
  end

  test "a valid claim link signs the invitee in and shows the welcome page" do
    raw = Auth::InvitationService.invite!(
      email: "nat.claim@example.com", first_name: "Nat", last_name: "McCarty", invited_by: @admin
    ).raw_token

    get invitation_path(token: raw)
    assert_response :success
    assert_select "h1", text: /Welcome/
    # Signed in: the dashboard is reachable without a login redirect.
    get dashboard_path
    assert_response :success
  end

  test "an invalid claim link redirects to the auth page" do
    get invitation_path(token: "garbage")
    assert_redirected_to auth_path
    follow_redirect!
    assert_match "no longer valid", flash[:alert]
  end
end
