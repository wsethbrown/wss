require "test_helper"

class Bottles::EditsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:john)
    @bottle = bottles(:eagle_rare)
  end

  test "signed-in user can view the pre-filled suggest-a-correction form" do
    get new_bottle_edit_path(@bottle)
    assert_response :success
    assert_select "input[name='bottle_edit[region]'][value=?]", @bottle.region
  end

  test "signed-out user is redirected to sign in" do
    sign_out users(:john)
    get new_bottle_edit_path(@bottle)
    assert_redirected_to new_user_session_path
  end

  test "submitting with only unchanged fields creates no proposals" do
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: @bottle.region, style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    assert_redirected_to bottle_path(@bottle)
  end

  test "submitting a changed field creates exactly one proposal for that field" do
    assert_difference "BottleEdit.count", 1 do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    edit = BottleEdit.last
    assert_equal "region", edit.field
    assert_equal "Highlands", edit.proposed_value
    assert_equal users(:john), edit.user
    assert_equal "pending", edit.status
  end

  test "submitting multiple changed fields creates one proposal per changed field" do
    assert_difference "BottleEdit.count", 2 do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: "New Distillery Co",
        region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    fields = BottleEdit.order(:id).last(2).map(&:field)
    assert_equal %w[distillery region], fields.sort
  end

  test "abv is normalized before the changed-value comparison" do
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: @bottle.region, style: @bottle.style, abv: "45.00"
      } }
    end
  end

  test "a resubmission while a proposal is already live updates nothing new (unique index holds)" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
  end

  test "clearing a populated field proposes nothing instead of dead-ending on a 422" do
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: "", distillery: @bottle.distillery,
        region: @bottle.region, style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    assert_redirected_to bottle_path(@bottle)
  end

  test "a different value on an already-proposed field replaces the user's pending suggestion" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    assert_no_difference "BottleEdit.count" do
      post bottle_edits_path(@bottle), params: { bottle_edit: {
        name: @bottle.name, distillery: @bottle.distillery,
        region: "Speyside", style: @bottle.style, abv: @bottle.abv.to_s
      } }
    end
    assert_equal "Speyside", edit.reload.proposed_value
    assert_equal "pending", edit.status
    assert_match(/on the record/, flash[:notice])
  end

  test "the third distinct user proposing the identical value auto-applies it" do
    BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    BottleEdit.create!(bottle: @bottle, user: users(:seth), field: "region", proposed_value: "Highlands")
    post bottle_edits_path(@bottle), params: { bottle_edit: {
      name: @bottle.name, distillery: @bottle.distillery,
      region: "Highlands", style: @bottle.style, abv: @bottle.abv.to_s
    } }
    assert_equal "Highlands", @bottle.reload.region
  end

  test "suggesting a correction never changes the bottle's slug" do
    original_slug = @bottle.slug
    BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "name", proposed_value: "Totally New Name")
    BottleEdit.create!(bottle: @bottle, user: users(:seth), field: "name", proposed_value: "Totally New Name")
    post bottle_edits_path(@bottle), params: { bottle_edit: {
      name: "Totally New Name", distillery: @bottle.distillery,
      region: @bottle.region, style: @bottle.style, abv: @bottle.abv.to_s
    } }
    @bottle.reload
    assert_equal "Totally New Name", @bottle.name
    assert_equal original_slug, @bottle.slug
  end
end
