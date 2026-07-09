require "test_helper"

# Century badge: users and societies with 100+ followers get an amber
# medallion next to their name on profiles, society pages, and reviews.
class CenturyBadgeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @society = societies(:whiskey_lovers)
  end

  test "century? flips at exactly 100 followers, counter-cache backed" do
    @user.update_column(:favorites_count, 99)
    assert_not @user.reload.century?

    @user.update_column(:favorites_count, 100)
    assert @user.reload.century?

    @society.update_column(:favorites_count, 100)
    assert @society.reload.century?
  end

  test "favoriting keeps the counter cache current" do
    assert_difference -> { @user.reload.favorites_count }, +1 do
      Favorite.create!(user: users(:jane), favoritable: @user)
    end
    assert_difference -> { @user.reload.favorites_count }, -1 do
      Favorite.find_by(user: users(:jane), favoritable: @user).destroy!
    end
  end

  test "profile shows the Century badge at 100+ followers and hides it below" do
    sign_in users(:jane)

    get profile_path(@user)
    assert_response :success
    assert_select "[title*='Century']", count: 0

    @user.update_column(:favorites_count, 150)
    get profile_path(@user)
    assert_select "[title*='Century']", count: 1
    assert_select "h1", text: /#{@user.first_name}/
  end

  private

  def sign_in(user)
    post "/users/sign_in", params: { user: { email: user.email, password: "password" } }
  end

  test "bottle-page review cards show the compact badge for Century authors" do
    bottle = bottles(:eagle_rare)
    assert bottle.reviews.exists?(user: @user), "fixture assumption: john reviewed eagle rare"

    get bottle_path(bottle)
    assert_response :success
    assert_select "[title*='Century']", count: 0

    @user.update_column(:favorites_count, 150)
    get bottle_path(bottle)
    assert_select "[title*='Century']", minimum: 1
  end

  test "society masthead shows the Century badge at 100+ followers" do
    @society.update!(is_private: false)
    @society.update_column(:favorites_count, 120)

    get society_path(@society)
    assert_response :success
    assert_select "[title*='Century']", count: 1
  end
end
