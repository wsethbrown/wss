require "test_helper"

# The "Tasting nights" feed: one card per society night, browsable by anyone.
# Public societies only; private nights stay veiled.
class TastingNightsFeedTest < ActionDispatch::IntegrationTest
  test "nights feed shows one card per public-society night with room scores" do
    get reviews_path(feed: "nights")
    assert_response :success

    event = events(:spring_blind)
    assert_select "article" do
      assert_select "a", text: event.society.name
    end
    assert_match event.title, response.body
    # Ardbeg's night mean: john 4.5 + seth's spring review, averaged.
    ardbeg_reviews = event.reviews.where(bottle: bottles(:ardbeg_10))
    mean = (ardbeg_reviews.sum(:rating) / ardbeg_reviews.count).round(2)
    assert_match ActionController::Base.helpers.number_with_precision(mean, precision: 2, strip_insignificant_zeros: true), response.body
    assert_select "a", text: /See the night/
  end

  test "private-society nights never appear in the feed" do
    private_review = reviews(:jane_allocated_four_roses)
    assert private_review.event.society.private?, "fixture assumption: allocated_night is private"

    get reviews_path(feed: "nights")
    assert_response :success
    assert_no_match private_review.event.society.name, response.body
    assert_no_match private_review.event.title, response.body
  end

  test "society chip filters the feed to that society" do
    society = societies(:single_malt)
    get reviews_path(feed: "nights", society: society.id)
    assert_response :success

    assert_select "h2", text: "Tasting nights · #{society.name}"
    assert_select "a", text: "All societies"
  end

  test "a private society id in the URL falls back to the unfiltered feed" do
    get reviews_path(feed: "nights", society: societies(:bourbon_club).id)
    assert_response :success

    assert_select "h2", text: "From society tasting nights"
    assert_no_match societies(:bourbon_club).name, response.body
  end
end
