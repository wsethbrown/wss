require "test_helper"

class BottleEditTest < ActiveSupport::TestCase
  setup { @bottle = bottles(:eagle_rare) }

  test "valid with a whitelisted field and a live status" do
    edit = BottleEdit.new(bottle: @bottle, user: users(:john), field: "distillery", proposed_value: "New Co")
    assert edit.valid?
  end

  test "field must be one of the whitelisted columns" do
    edit = BottleEdit.new(bottle: @bottle, user: users(:john), field: "slug", proposed_value: "hijacked")
    assert_not edit.valid?
    assert_includes edit.errors[:field], "is not included in the list"
  end

  test "status defaults to pending" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    assert_equal "pending", edit.status
  end

  test "status must be one of the known values" do
    edit = BottleEdit.new(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands", status: "bogus")
    assert_not edit.valid?
    assert_includes edit.errors[:status], "is not included in the list"
  end

  test "one live proposal per user per field per bottle" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    dupe = BottleEdit.new(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Speyside")
    assert_not dupe.valid?
    assert_includes dupe.errors[:user_id], "has already been taken"
  end

  test "a user may propose again on the same field once their prior proposal resolved" do
    first = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    first.update!(status: "rejected")
    second = BottleEdit.new(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Speyside")
    assert second.valid?
  end

  test "the same user may hold live proposals on two different fields" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    other_field = BottleEdit.new(bottle: @bottle, user: users(:john), field: "style", proposed_value: "Bourbon")
    assert other_field.valid?
  end

  test "two different users may each propose the same field live at once" do
    BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    other_user = BottleEdit.new(bottle: @bottle, user: users(:jane), field: "region", proposed_value: "Highlands")
    assert other_user.valid?
  end

  test "Bottle#bottle_edits returns its proposals" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "region", proposed_value: "Highlands")
    assert_includes @bottle.bottle_edits, edit
  end

  test "FIELDS is the exact five-column whitelist" do
    assert_equal %w[name distillery region style abv], BottleEdit::FIELDS
  end

  test "default auto-apply threshold is 3" do
    assert_equal 3, Rails.application.config.x.bottle_edits.auto_apply_threshold
  end

  test "proposed_value is capped so nobody can store a multi-megabyte proposal" do
    edit = BottleEdit.new(bottle: @bottle, user: users(:john), field: "name", proposed_value: "a" * 501)
    assert_not edit.valid?
    assert_includes edit.errors[:proposed_value], "is too long (maximum is 500 characters)"
  end

  test "proposed_value normalizes on save so every write path groups identically" do
    edit = BottleEdit.create!(bottle: @bottle, user: users(:john), field: "abv", proposed_value: "45")
    assert_equal "45.0", edit.proposed_value

    trailing_zeros = BottleEdit.create!(bottle: @bottle, user: users(:jane), field: "abv", proposed_value: "45.00")
    assert_equal "45.0", trailing_zeros.proposed_value
  end
end
