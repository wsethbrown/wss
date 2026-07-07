require "test_helper"

class ReviewsTest < ActionDispatch::IntegrationTest
  test "review requires sign in" do
    get new_bottle_review_path(bottles(:lagavulin))
    assert_redirected_to new_user_session_path
  end

  test "creates a solo review" do
    sign_in users(:jane)
    assert_difference "Review.count", 1 do
      post bottle_reviews_path(bottles(:lagavulin)), params: { review: {
        rating: "4.5", notes: "Campfire and sea spray.", nose: "Peat smoke",
        palate: "Brine, vanilla", finish: "Endless smoke", body_notes: "Oily"
      } }
    end
    review = Review.last
    assert_equal users(:jane), review.user
    assert review.solo?
    assert_redirected_to review_path(review) # straight to your own tasting
  end

  test "second solo review of the same bottle is rejected" do
    sign_in users(:john) # fixture john_eagle_rare exists
    assert_no_difference "Review.count" do
      post bottle_reviews_path(bottles(:eagle_rare)), params: { review: { rating: "3.0" } }
    end
    assert_response :unprocessable_entity
  end

  test "author can edit their review" do
    sign_in users(:john)
    patch review_path(reviews(:john_eagle_rare)), params: { review: { rating: "3.5", notes: "Revisited: softer than I remembered." } }
    assert_redirected_to review_path(reviews(:john_eagle_rare))
    assert_equal 3.5, reviews(:john_eagle_rare).reload.rating.to_f
  end

  test "non-author cannot edit or destroy" do
    sign_in users(:jane)
    patch review_path(reviews(:john_eagle_rare)), params: { review: { rating: "1.0" } }
    assert_response :not_found
    assert_equal 4.0, reviews(:john_eagle_rare).reload.rating.to_f
  end

  test "author can delete their review" do
    sign_in users(:john)
    assert_difference "Review.count", -1 do
      delete review_path(reviews(:john_eagle_rare))
    end
    assert_redirected_to bottle_path(bottles(:eagle_rare))
  end
end

class ReviewFormStarsTest < ActionDispatch::IntegrationTest
  test "the review form renders the half-star widget with a hidden rating field" do
    sign_in users(:jane)
    get new_bottle_review_path(bottles(:lagavulin))
    assert_response :success
    assert_select "[data-controller=star-rating]"
    assert_select "input[type=hidden][name=?]", "review[rating]"
    assert_select "button[data-value='0.5']"
    assert_select "button[data-value='5.0']"
  end
end
