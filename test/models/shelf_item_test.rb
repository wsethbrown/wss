require "test_helper"

class ShelfItemTest < ActiveSupport::TestCase
  test "valid with a bottle and no custom name" do
    item = ShelfItem.new(user: users(:john), bottle: bottles(:ardbeg_10), position: 1)
    assert item.valid?
  end

  test "valid with a custom name and no bottle" do
    item = ShelfItem.new(user: users(:john), custom_name: "Grandpa's mystery rye", position: 1)
    assert item.valid?
  end

  test "invalid with neither bottle nor custom name" do
    item = ShelfItem.new(user: users(:john), position: 1)
    assert_not item.valid?
  end

  test "invalid with both bottle and custom name" do
    item = ShelfItem.new(user: users(:john), bottle: bottles(:ardbeg_10), custom_name: "Ardbeg", position: 1)
    assert_not item.valid?
  end

  test "same bottle cannot be shelved twice by one user" do
    ShelfItem.create!(user: users(:john), bottle: bottles(:ardbeg_10), position: 1)
    dup = ShelfItem.new(user: users(:john), bottle: bottles(:ardbeg_10), position: 2)
    assert_not dup.valid?
    assert ShelfItem.new(user: users(:jane), bottle: bottles(:ardbeg_10), position: 1).valid?
  end

  test "custom name is unique per user, case-insensitively" do
    ShelfItem.create!(user: users(:john), custom_name: "The blind pour", position: 1)
    dup = ShelfItem.new(user: users(:john), custom_name: "the BLIND pour", position: 2)
    assert_not dup.valid?
    assert ShelfItem.new(user: users(:jane), custom_name: "The blind pour", position: 1).valid?
  end

  test "display_name uses the bottle name for linked entries and custom_name otherwise" do
    linked = ShelfItem.new(user: users(:john), bottle: bottles(:ardbeg_10), position: 1)
    free = ShelfItem.new(user: users(:john), custom_name: "Grandpa's mystery rye", position: 2)
    assert_equal "Ardbeg 10", linked.display_name
    assert_equal "Grandpa's mystery rye", free.display_name
  end

  test "user shelf_items are ordered by position and cleaned up with the user" do
    second = ShelfItem.create!(user: users(:john), custom_name: "B", position: 2)
    first = ShelfItem.create!(user: users(:john), custom_name: "A", position: 1)
    assert_equal [ first, second ], users(:john).shelf_items.to_a
    assert_equal :destroy, User.reflect_on_association(:shelf_items).options[:dependent]
  end
end
