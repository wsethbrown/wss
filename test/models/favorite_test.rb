require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "a user can favorite a public society" do
    assert Favorite.new(user: users(:jane), favoritable: societies(:whiskey_lovers)).valid?
  end

  test "a user can favorite another user" do
    assert Favorite.new(user: users(:jane), favoritable: users(:john)).valid?
  end

  test "duplicate favorite is invalid" do
    Favorite.create!(user: users(:jane), favoritable: users(:john))
    dup = Favorite.new(user: users(:jane), favoritable: users(:john))
    assert_not dup.valid?
    assert_includes dup.errors[:favoritable_id], "has already been taken"
  end

  test "cannot favorite yourself" do
    fav = Favorite.new(user: users(:jane), favoritable: users(:jane))
    assert_not fav.valid?
    assert_includes fav.errors[:favoritable], "can't be yourself"
  end

  test "cannot favorite a private society you cannot see" do
    fav = Favorite.new(user: users(:john), favoritable: societies(:bourbon_club))
    assert_not fav.valid?
    assert_includes fav.errors[:favoritable], "isn't visible to you"
  end

  test "a member CAN favorite the private society they belong to" do
    assert Favorite.new(user: users(:jane), favoritable: societies(:bourbon_club)).valid? # jane is creator
  end
end
