require "test_helper"

class ProfileShelfTest < ActionDispatch::IntegrationTest
  setup do
    @john = users(:john)
    sign_in users(:jane)
  end

  test "linked entries render as bottle links with community rating when reviews exist" do
    ShelfItem.create!(user: @john, bottle: bottles(:eagle_rare), position: 1)
    get profile_path(@john)
    assert_response :success
    assert_select "#whiskey-shelf a[href=?]", bottle_path(bottles(:eagle_rare)), text: "Eagle Rare 10"
    shelf = css_select("#whiskey-shelf").first.text
    assert_includes shelf, "4.0"
    assert_includes shelf, "1 tasting"
  end

  test "linked entries without reviews render a link but no rating" do
    ShelfItem.create!(user: @john, bottle: bottles(:lagavulin), position: 1)
    get profile_path(@john)
    assert_select "#whiskey-shelf a[href=?]", bottle_path(bottles(:lagavulin)), text: "Lagavulin 16"
    assert_not_includes css_select("#whiskey-shelf").first.text, "tasting"
  end

  test "free-text entries render as plain text without a link" do
    ShelfItem.create!(user: @john, custom_name: "Grandpa's mystery rye", position: 1)
    get profile_path(@john)
    assert_includes css_select("#whiskey-shelf").first.text, "Grandpa's mystery rye"
    assert_select "#whiskey-shelf a", count: 0
  end

  test "no shelf section without shelf items, even with legacy text" do
    @john.update_column(:whiskey_shelf, "Macallan 18\nSomething else")
    get profile_path(@john)
    assert_select "#whiskey-shelf", count: 0
  end
end
