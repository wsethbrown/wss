require "test_helper"

# The invite-link peek (owner-approved, July 2026): a signed-out visitor
# gets a society introduction instead of an auth wall, and whoever signs
# up or in afterwards joins that society automatically.
class InvitePeekTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:john)
    @society = Society.create!(name: "Peek Club", description: "A club worth peeking at",
                               creator: @creator, is_private: false)
    @token = @society.invite_token!
  end

  test "a signed-out visitor sees the peek, not an auth wall" do
    get society_invite_path(@token)
    assert_response :success
    assert_match "Peek Club", response.body
    assert_match "Pull up a chair", response.body
    assert_equal @token, session[:pending_invite_token]
  end

  test "a private society peeks without member identities" do
    hidden = users(:jane)
    @society.update!(is_private: true)
    SocietyMembership.create!(user: hidden, society: @society, role: "member", status: "active")
    get society_invite_path(@token)
    assert_response :success
    assert_match "Peek Club", response.body
    assert_match "A private society", response.body
    assert_no_match hidden.full_name, response.body
    assert_no_match @creator.full_name, response.body
  end

  test "an invalid token redirects" do
    get society_invite_path("bogus")
    assert_redirected_to root_path
  end

  test "signing in after the peek joins the society" do
    get society_invite_path(@token)
    member = users(:jane)
    post user_session_path, params: { user: { email: member.email, password: "password" } }
    5.times { follow_redirect! if response.redirect? }
    assert @society.society_memberships.exists?(user: member, status: "active")
  end

  test "creating an account after the peek joins the society" do
    get society_invite_path(@token)
    post user_registration_path, params: { user: {
      first_name: "Peek", last_name: "Joiner", email: "peek.joiner@example.com",
      password: "secret123", password_confirmation: "secret123"
    } }
    5.times { follow_redirect! if response.redirect? }
    joiner = User.find_by(email: "peek.joiner@example.com")
    assert joiner
    assert @society.society_memberships.exists?(user: joiner, status: "active")
  end

  test "a signed-in visitor still joins immediately" do
    sign_in users(:jane)
    get society_invite_path(@token)
    assert_redirected_to society_path(@society)
    assert @society.society_memberships.exists?(user: users(:jane), status: "active")
  end

  test "the review board section renders when the society has tastings" do
    society = societies(:single_malt)
    get society_invite_path(society.invite_token!)
    assert_response :success
    assert_match "From the review board", response.body
  end
end
