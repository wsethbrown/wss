require "test_helper"

class BottleCreationTest < ActionDispatch::IntegrationTest
  test "requires sign in" do
    get new_bottle_path
    assert_redirected_to new_user_session_path
  end

  test "creates a bottle and lands on its page" do
    sign_in users(:jane)
    assert_difference "Bottle.count", 1 do
      post bottles_path, params: { bottle: {
        name: "Redbreast 12", distillery: "Midleton", region: "Ireland",
        style: "Single Pot Still", abv: 40.0
      } }
    end
    bottle = Bottle.find_by!(name: "Redbreast 12")
    assert_equal users(:jane), bottle.created_by
    assert_redirected_to bottle_path(bottle)
  end

  test "near-match warns instead of creating, then creates when confirmed" do
    sign_in users(:jane)
    assert_no_difference "Bottle.count" do
      post bottles_path, params: { bottle: { name: "Eagle Rare" } }
    end
    assert_response :unprocessable_entity
    assert_match "Eagle Rare 10", response.body # the existing near-match, offered as a link

    assert_difference "Bottle.count", 1 do
      post bottles_path, params: { bottle: { name: "Eagle Rare" }, confirmed_duplicate: "1" }
    end
  end

  test "invalid bottle re-renders the form" do
    sign_in users(:jane)
    assert_no_difference "Bottle.count" do
      post bottles_path, params: { bottle: { name: "" } }
    end
    assert_response :unprocessable_entity
  end
end
