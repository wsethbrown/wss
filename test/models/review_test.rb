require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "valid solo review saves" do
    review = Review.new(user: users(:jane), bottle: bottles(:lagavulin), rating: 4.5,
                        notes: "Peat and honey.")
    assert review.valid?, review.errors.full_messages.to_sentence
  end

  test "rating must be a half step between 0.5 and 5.0" do
    review = reviews(:john_eagle_rare)
    [0.0, 5.5, 4.3, -1].each do |bad|
      review.rating = bad
      assert_not review.valid?, "#{bad} should be invalid"
    end
    [0.5, 3.0, 4.5, 5.0].each do |good|
      review.rating = good
      assert review.valid?, "#{good} should be valid"
    end
  end

  test "one solo review per user per bottle" do
    dup = Review.new(user: users(:john), bottle: bottles(:eagle_rare), rating: 3.0)
    assert_not dup.valid?
    assert_includes dup.errors[:bottle_id], "already has your review — edit it instead"
  end

  test "solo? distinguishes event-tagged reviews" do
    assert reviews(:john_eagle_rare).solo?
  end

  test "average_rating uses each user's latest review" do
    bottle = bottles(:eagle_rare) # fixture review: john at 4.0
    Review.create!(user: users(:jane), bottle: bottle, rating: 5.0)
    assert_in_delta 4.5, bottle.average_rating, 0.001
    assert_equal 2, bottle.reviewer_count
  end

  test "average_rating is nil with no reviews" do
    assert_nil bottles(:lagavulin).average_rating
    assert_equal 0, bottles(:lagavulin).reviewer_count
  end

  test "average_rating uses only a user's newer review when they reviewed the same bottle twice" do
    bottle = bottles(:eagle_rare) # fixture review: john at 4.0, created via fixtures (treated as older)
    old_review = reviews(:john_eagle_rare)
    old_review.update_column(:created_at, 2.days.ago)

    event = Event.create!(
      society: societies(:whiskey_lovers),
      organizer: users(:john),
      title: "Eagle Rare Re-tasting",
      start_time: 3.days.from_now, # comfortably outside the 24h RSVP cutoff
      end_time: 3.days.from_now + 2.hours
    )

    event.event_bottles.create!(bottle: bottle, position: 1)
    event.event_rsvps.create!(user: users(:john), status: "yes")
    newer_review = Review.create!(user: users(:john), bottle: bottle, event: event, rating: 2.0)
    newer_review.update_column(:created_at, 1.day.ago)

    assert_in_delta 2.0, bottle.average_rating, 0.001
    assert_equal 1, bottle.reviewer_count
  end

  test "hot_ranked orders by votes within the window, ties newest first" do
    old_review, new_review = reviews(:john_spring_glendronach), reviews(:john_spring_four_roses)
    ReviewVote.create!(user: users(:seth), review: old_review)
    ReviewVote.where(review: old_review).update_all(created_at: 45.days.ago) # push outside the window
    ReviewVote.create!(user: users(:jane), review: new_review) # in-window

    ranked = Review.hot_ranked.to_a
    assert_operator ranked.index(new_review), :<, ranked.index(old_review)
  end

  test "hot_ranked includes zero-vote reviews (LEFT JOIN)" do
    assert_includes Review.hot_ranked.to_a, reviews(:seth_spring_glendronach)
  end
end

class ReviewDescriptorTest < ActiveSupport::TestCase
  test "descriptor_tags lifts lexicon words from tasting fields only" do
    r = Review.new(nose: "Peat smoke and honey", palate: "brine, vanilla",
                   notes: "cherry bomb (notes are NOT scanned)")
    assert_equal({ "peat" => "smoky", "smoke" => "smoky", "honey" => "sweet",
                   "brine" => "coastal", "vanilla" => "sweet" }, r.descriptor_tags)
    assert_equal({ "smoky" => 2, "sweet" => 2, "coastal" => 1 }, r.flavor_profile)
  end

  test "tagged scope matches all given tags, words and families alike" do
    r = reviews(:john_eagle_rare) # nose "Toffee, orange peel", palate "Cherry, leather"
    assert_includes Review.tagged(["toffee"]), r
    assert_includes Review.tagged(["toffee", "cherry"]), r
    assert_includes Review.tagged(["sweet"]), r          # family covers toffee
    assert_not_includes Review.tagged(["peat"]), r
    assert_not_includes Review.tagged(["toffee", "peat"]), r # ALL must match
  end
end
