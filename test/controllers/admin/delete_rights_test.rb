require "test_helper"

# admin_role tiers: `full` can hard-delete records, `limited` is a full admin
# minus delete rights, `none` is a normal user.
class Admin::DeleteRightsTest < ActionDispatch::IntegrationTest
  def a_deck
    Presentation.create!(author: users(:admin), title: "Doomed Deck", content: "x", price: 5)
  end

  # ---- model ---------------------------------------------------------------
  test "admin? is true for both admin tiers, false for a normal user" do
    assert users(:admin).admin?,          "full admin is an admin"
    assert users(:limited_admin).admin?,  "limited admin is an admin"
    assert_not users(:john).admin?,       "normal user is not an admin"
  end

  test "only full admins can delete" do
    assert users(:admin).can_delete?
    assert_not users(:limited_admin).can_delete?
    assert_not users(:john).can_delete?
  end

  # ---- admin panel access --------------------------------------------------
  test "a limited admin can still reach the admin panel" do
    sign_in users(:limited_admin)
    get admin_presentations_path
    assert_response :success
  end

  # ---- hard-delete gating (admin panel) ------------------------------------
  test "a full admin can delete a deck" do
    deck = a_deck
    sign_in users(:admin)
    assert_difference("Presentation.count", -1) do
      delete admin_presentation_path(deck)
    end
  end

  test "a limited admin cannot delete a deck" do
    deck = a_deck
    sign_in users(:limited_admin)
    assert_no_difference("Presentation.count") do
      delete admin_presentation_path(deck)
    end
    assert_response :redirect
  end

  # ---- policy-level delete gating ------------------------------------------
  test "a limited admin cannot destroy a society via the admin override" do
    society = societies(:whiskey_lovers)
    assert SocietyPolicy.new(users(:admin), society).destroy?,          "full admin can"
    assert_not SocietyPolicy.new(users(:limited_admin), society).destroy?, "limited admin cannot"
  end

  test "a society owner can still delete their own society regardless of admin tier" do
    society = societies(:whiskey_lovers)
    owner = society.creator
    assert SocietyPolicy.new(owner, society).destroy?
  end
end
