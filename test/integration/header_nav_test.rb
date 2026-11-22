require "test_helper"

# The header logo always goes home; signed-in users reach their dashboard
# through an explicit "Dashboard" link, first in both the desktop nav and the
# mobile menu.
class HeaderNavTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: "header-nav@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Header",
      last_name: "Nav"
    )
  end

  def sign_in_user
    post user_session_path, params: { user: { email: @user.email, password: "password123" } }
  end

  test "signed-in header logo links to the home page and / renders for them" do
    sign_in_user
    get root_path
    assert_response :success
    assert_select "nav > div > a:first-child[href=?]", "/"
    assert_select "nav a[href=?] img[alt=?]", "/", "Whiskey Share Society"
  end

  test "signed-in nav has a Dashboard link in the desktop nav and the mobile menu" do
    sign_in_user
    get account_path
    assert_response :success
    assert_select "nav div.hidden.md\\:flex a[href=?]", "/dashboard", text: "Dashboard", count: 1
    assert_select "nav details a[href=?]", "/dashboard", text: "Dashboard", count: 1
    # First, before Societies, in both menus.
    assert_select "nav div.hidden.md\\:flex > a:first-child[href=?]", "/dashboard"
    assert_select "nav details > div > a:first-child[href=?]", "/dashboard"
  end

  test "signed-out nav has no Dashboard link and the logo goes home" do
    get root_path
    assert_response :success
    assert_select "nav a[href=?]", "/dashboard", count: 0
    assert_select "nav a[href=?] img[alt=?]", "/", "Whiskey Share Society"
  end
end
