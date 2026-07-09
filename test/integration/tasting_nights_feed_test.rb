require "test_helper"

# The "Tasting nights" feed: society event reviews, browsable by anyone —
# public societies only, private nights stay veiled.
class TastingNightsFeedTest < ActionDispatch::IntegrationTest
  test "nights feed shows public-society event reviews to signed-out visitors" do
    get reviews_path(feed: "nights")
    assert_response :success

    # spring_blind belongs to single_malt (public) — its reviews appear.
    assert_match reviews(:john_spring_ardbeg).bottle.name, response.body
    assert_select "h2", text: "From society tasting nights"
  end

  test "private-society nights never appear in the feed" do
    private_review = reviews(:jane_allocated_four_roses)
    assert private_review.event.society.private?, "fixture assumption: allocated_night is private"

    get reviews_path(feed: "nights")
    assert_response :success
    assert_no_match private_review.event.society.name, response.body
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
