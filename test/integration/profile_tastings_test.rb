require "test_helper"

class ProfileTastingsTest < ActionDispatch::IntegrationTest
  test "profile shows the member's tastings" do
    sign_in users(:jane)
    get profile_path(users(:john))
    assert_response :success
    assert_match "Eagle Rare 10", response.body
    assert_match "Tastings", response.body
  end

  test "nav links to the reviews section" do
    get root_path
    assert_select "nav a[href=?]", reviews_path
  end
end
