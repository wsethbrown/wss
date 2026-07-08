require "test_helper"

class BottleEdits::AutoApplyTest < ActiveSupport::TestCase
  setup { @bottle = bottles(:eagle_rare) }

  def propose(user, field, value)
    normalized_value = BottleEdits::Normalize.for_storage(field, value)
    BottleEdit.create!(bottle: @bottle, user: user, field: field, proposed_value: normalized_value)
  end

  test "does nothing below the threshold" do
    propose(users(:john), "region", "Highlands")
    propose(users(:jane), "region", "Highlands")
    assert_not BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "Kentucky", @bottle.reload.region
  end

  test "applies once the threshold of distinct users on the identical value is reached" do
    propose(users(:john), "region", "Highlands")
    propose(users(:jane), "region", "Highlands")
    propose(users(:seth), "region", "Highlands")
    assert BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "Highlands", @bottle.reload.region
  end

  test "applied rows are marked applied with a nil applied_by (auto)" do
    e1 = propose(users(:john), "region", "Highlands")
    e2 = propose(users(:jane), "region", "Highlands")
    e3 = propose(users(:seth), "region", "Highlands")
    BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    [ e1, e2, e3 ].each do |e|
      e.reload
      assert_equal "applied", e.status
      assert_nil e.applied_by_id
      assert_not_nil e.applied_at
    end
  end

  test "competing pending proposals on the same field are cleared (rejected) when one wins" do
    winner_users = [ users(:john), users(:jane), users(:seth) ]
    winner_users.each { |u| propose(u, "region", "Highlands") }
    loser = propose(users(:admin), "region", "Speyside")
    BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "rejected", loser.reload.status
    assert_nil loser.applied_at
  end

  test "does not touch pending proposals on a different field" do
    propose(users(:john), "region", "Highlands")
    propose(users(:jane), "region", "Highlands")
    propose(users(:seth), "region", "Highlands")
    other_field = propose(users(:one), "style", "Bourbon")
    BottleEdits::AutoApply.call(bottle: @bottle, field: "region")
    assert_equal "pending", other_field.reload.status
  end

  test "abv proposals normalize before grouping so 45, 45.0, and 45.00 count together" do
    propose(users(:john), "abv", "45")
    propose(users(:jane), "abv", "45.0")
    propose(users(:seth), "abv", "45.00")
    assert BottleEdits::AutoApply.call(bottle: @bottle, field: "abv")
    assert_equal "45.0".to_d, @bottle.reload.abv
  end

  test "does not apply a value that would fail bottle validation" do
    propose(users(:john), "abv", "500")
    propose(users(:jane), "abv", "500")
    propose(users(:seth), "abv", "500")
    assert_not BottleEdits::AutoApply.call(bottle: @bottle, field: "abv")
    assert_not_equal "500".to_d, @bottle.reload.abv
  end
end
