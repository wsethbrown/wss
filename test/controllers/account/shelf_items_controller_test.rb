require "test_helper"

class Account::ShelfItemsControllerTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    post account_shelf_items_path, params: { shelf_item: { bottle_id: bottles(:ardbeg_10).id } }
    assert_redirected_to new_user_session_path
  end

  test "adds a linked bottle to the shelf" do
    sign_in users(:john)
    assert_difference "ShelfItem.count", 1 do
      post account_shelf_items_path, params: { shelf_item: { bottle_id: bottles(:ardbeg_10).id } }
    end
    assert_redirected_to account_path(anchor: "profile")
    item = users(:john).shelf_items.last
    assert_equal bottles(:ardbeg_10), item.bottle
    assert_nil item.custom_name
  end

  test "adds a free-text entry without creating a bottle" do
    sign_in users(:john)
    assert_no_difference "Bottle.count" do
      assert_difference "ShelfItem.count", 1 do
        post account_shelf_items_path, params: { shelf_item: { custom_name: "Grandpa's mystery rye" } }
      end
    end
    assert_equal "Grandpa's mystery rye", users(:john).shelf_items.last.custom_name
  end

  test "appends after the current highest position" do
    sign_in users(:john)
    ShelfItem.create!(user: users(:john), custom_name: "First", position: 5)
    post account_shelf_items_path, params: { shelf_item: { custom_name: "Second" } }
    assert_equal 6, users(:john).shelf_items.last.position
  end

  test "rejects blank input" do
    sign_in users(:john)
    assert_no_difference "ShelfItem.count" do
      post account_shelf_items_path, params: { shelf_item: { custom_name: "  " } }
    end
    assert_redirected_to account_path(anchor: "profile")
    assert flash[:alert].present?
  end

  test "rejects a duplicate bottle" do
    sign_in users(:john)
    ShelfItem.create!(user: users(:john), bottle: bottles(:ardbeg_10), position: 1)
    assert_no_difference "ShelfItem.count" do
      post account_shelf_items_path, params: { shelf_item: { bottle_id: bottles(:ardbeg_10).id } }
    end
    assert flash[:alert].present?
  end

  test "removes an item from your own shelf" do
    sign_in users(:john)
    item = ShelfItem.create!(user: users(:john), custom_name: "Gone soon", position: 1)
    assert_difference "ShelfItem.count", -1 do
      delete account_shelf_item_path(item)
    end
    assert_redirected_to account_path(anchor: "profile")
  end

  test "cannot remove another user's item" do
    sign_in users(:john)
    item = ShelfItem.create!(user: users(:jane), custom_name: "Jane's pick", position: 1)
    assert_no_difference "ShelfItem.count" do
      delete account_shelf_item_path(item)
    end
    assert_response :not_found
  end
end
