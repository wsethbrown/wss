require "test_helper"

class ProfileFollowersTest < ActionDispatch::IntegrationTest
  test "followers_count counts who favorites the user, not who the user favorites" do
    john = users(:john)
    jane = users(:jane)

    Favorite.create!(user: jane, favoritable: john) # jane follows john
    assert_equal 1, john.reload.followers_count
    # John favoriting someone else does not add to his own follower count.
    assert_equal 0, jane.reload.followers_count
  end

  test "the profile page shows the follower count" do
    john = users(:john)
    Favorite.create!(user: users(:jane), favoritable: john)

    sign_in users(:seth)
    get profile_path(john)
    assert_response :success
    assert_select "span", text: /1 follower/
  end

  private

  def sign_in(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password" } }
  end
end
