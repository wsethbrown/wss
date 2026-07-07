require "test_helper"

class BottleTest < ActiveSupport::TestCase
  test "requires a name" do
    bottle = Bottle.new(name: "")
    assert_not bottle.valid?
    assert_includes bottle.errors[:name], "can't be blank"
  end

  test "generates a slug from name and distillery" do
    bottle = Bottle.create!(name: "Eagle Rare 10", distillery: "Buffalo Trace")
    assert_equal "eagle-rare-10-buffalo-trace", bottle.slug
    assert_equal bottle.slug, bottle.to_param
  end

  test "deduplicates slugs with a numeric suffix" do
    Bottle.create!(name: "Lagavulin 16")
    second = Bottle.create!(name: "Lagavulin 16")
    assert_equal "lagavulin-16-2", second.slug
  end

  test "search matches name and distillery case-insensitively" do
    eagle = bottles(:eagle_rare)
    assert_includes Bottle.search("eagle"), eagle
    assert_includes Bottle.search("BUFFALO"), eagle
    assert_not_includes Bottle.search("laphroaig"), eagle
  end

  test "display_name combines name and distillery" do
    assert_equal "Eagle Rare 10 — Buffalo Trace", bottles(:eagle_rare).display_name
    assert_equal "Housemade Amaro", Bottle.new(name: "Housemade Amaro").display_name
  end
end
