require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User"
    )
  end

  test "requesting a magic link for an existing user stores a hashed token" do
    post magic_links_path, params: { email: @user.email }

    assert_redirected_to auth_path
    assert_match(/magic link/i, flash[:notice])

    @user.reload
    assert_not_nil @user.magic_link_token
    assert_not_nil @user.magic_link_sent_at
    # Password-reset fields are untouched (no more collision).
    assert_nil @user.reset_password_token
  end

  test "requesting a magic link for a new email does not create a user yet" do
    assert_no_difference -> { User.count } do
      post magic_links_path, params: { email: "newuser@example.com" }
    end

    assert_redirected_to auth_path
    assert_match(/magic link/i, flash[:notice])
  end

  test "clicking a valid magic link signs the user in" do
    raw = "integration-raw-token"
    @user.update!(magic_link_token: Auth::MagicLinkService.digest(raw), magic_link_sent_at: Time.current)

    get magic_link_path(token: raw)

    assert_redirected_to account_path
    assert_match(/signed in/i, flash[:notice])
    assert_nil @user.reload.magic_link_token, "token is consumed on use"
  end

  test "an invalid magic link is rejected" do
    get magic_link_path(token: "not-a-real-token")

    assert_redirected_to auth_path
    assert_match(/invalid or has expired/i, flash[:alert])
  end
end
