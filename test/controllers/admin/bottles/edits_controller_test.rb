require "test_helper"

class Admin::Bottles::EditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @bottle = bottles(:eagle_rare)
  end

  test "admin can apply a single pending proposal" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to admin_bottle_path(@bottle)
    assert_equal "Highlands", @bottle.reload.region
    edit.reload
    assert_equal "applied", edit.status
    assert_equal users(:admin), edit.applied_by
    assert_not_nil edit.applied_at
  end

  test "applying one proposal clears competing pending proposals on the same field" do
    winner = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    loser = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Speyside")
    other_field = BottleEdit.create!(bottle: @bottle, user: users(:seth), field: "style", proposed_value: "Bourbon")
    post apply_admin_bottle_edit_path(@bottle, winner)
    assert_equal "rejected", loser.reload.status
    assert_equal "pending", other_field.reload.status
  end

  test "applying one proposal also applies co-proposers of the identical value" do
    a = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    b = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(@bottle, a)
    assert_equal "applied", b.reload.status
    assert_equal users(:admin), b.applied_by
  end

  test "admin can reject a single proposal without touching others" do
    reject_me = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    leave_me = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    delete admin_bottle_edit_path(@bottle, reject_me)
    assert_redirected_to admin_bottle_path(@bottle)
    assert_equal "rejected", reject_me.reload.status
    assert_equal "pending", leave_me.reload.status
    assert_not_equal "Highlands", @bottle.reload.region
  end

  test "applying a proposal with invalid data re-renders without crashing" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "abv", proposed_value: "500.0")
    post apply_admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to admin_bottle_path(@bottle)
    assert_equal "pending", edit.reload.status
    assert_not_equal "500.0".to_d, @bottle.reload.abv
  end

  test "non-admin cannot apply or reject" do
    sign_out users(:admin)
    sign_in users(:john)
    edit = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to root_path
    delete admin_bottle_edit_path(@bottle, edit)
    assert_redirected_to root_path
    assert_equal "pending", edit.reload.status
  end

  test "an edit addressed under the wrong bottle's URL is not found" do
    other_bottle = bottles(:lagavulin)
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    post apply_admin_bottle_edit_path(other_bottle, edit)
    assert_response :not_found
  end
end
