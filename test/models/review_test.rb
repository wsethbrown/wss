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
end
