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

  test "updating name or distillery after creation does not regenerate the slug" do
    bottle = bottles(:eagle_rare)
    original_slug = bottle.slug
    bottle.update!(name: "Eagle Rare Renamed", distillery: "New Distillery Co")
    assert_equal original_slug, bottle.slug
  end

  test "search matches name and distillery case-insensitively" do
    eagle = bottles(:eagle_rare)
    assert_includes Bottle.search("eagle"), eagle
    assert_includes Bottle.search("BUFFALO"), eagle
    assert_not_includes Bottle.search("laphroaig"), eagle
  end

  test "display_name combines name and distillery" do
    assert_equal "Eagle Rare 10 · Buffalo Trace", bottles(:eagle_rare).display_name
    assert_equal "Housemade Amaro", Bottle.new(name: "Housemade Amaro").display_name
  end
end

class BottlePriceSummaryTest < ActiveSupport::TestCase
  test "price summary: nil, median when thin, IQR when 4+" do
    bottle = bottles(:lagavulin)
    assert_nil bottle.price_summary

    r1 = Review.create!(user: users(:jane), bottle: bottle, rating: 4.0, price_paid: 90)
    assert_equal({ median: 90.0, count: 1 }, bottle.price_summary)

    Review.create!(user: users(:john), bottle: bottle, rating: 4.0, price_paid: 70)
    Review.create!(user: users(:seth), bottle: bottle, rating: 4.0, price_paid: 80)
    Review.create!(user: users(:admin), bottle: bottle, rating: 4.0, price_paid: 300) # the airport bottle
    summary = bottle.price_summary
    assert_equal 4, summary[:count]
    assert_in_delta 77.5, summary[:low], 0.01
    assert_in_delta 142.5, summary[:high], 0.01 # IQR blunts but includes the outlier's pull
  end
end
