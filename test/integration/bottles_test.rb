require "test_helper"

class BottlesTest < ActionDispatch::IntegrationTest
  test "index lists bottles and recent reviews, signed out" do
    get reviews_path
    assert_response :success
    assert_select "h1", text: /The tasting record/i
    assert_match "Eagle Rare 10", response.body
    assert_match "Cherry and oak", response.body # recent review feed
  end

  test "index filters by search term" do
    get reviews_path(q: "lagavulin")
    assert_response :success
    assert_match "Lagavulin 16", response.body
    assert_no_match "Eagle Rare 10", response.body
  end

  test "search also finds public societies, never private ones for outsiders" do
    get reviews_path(q: "society") # matches public "Whiskey Lovers Society"
    assert_response :success
    assert_match "Whiskey Lovers Society", response.body

    get reviews_path(q: "bourbon club") # matches only the private club
    assert_response :success
    assert_no_match "Exclusive Bourbon Club", response.body
  end

  test "section search JSON groups bottles and societies, policy-scoped" do
    get search_reviews_path(q: "society", format: :json)
    assert_response :success
    body = response.parsed_body
    assert_includes body["societies"].map { |s| s["label"] }, "Whiskey Lovers Society"

    get search_reviews_path(q: "bourbon club", format: :json)
    assert_response :success
    assert_empty response.parsed_body["societies"], "private society leaked to signed-out search"
  end

  test "start-a-review picker requires sign in, then renders" do
    get start_reviews_path
    assert_redirected_to new_user_session_path

    sign_in users(:jane)
    get start_reviews_path
    assert_response :success
    assert_match "What did you taste?", response.body
  end

  test "bottle search JSON includes the review shortcut url" do
    get search_bottles_path(q: "eagle", format: :json)
    match = response.parsed_body.find { |b| b["name"] == "Eagle Rare 10" }
    assert_match %r{/bottles/.+/reviews/new}, match["review_url"]
  end

  test "search endpoint returns JSON matches" do
    get search_bottles_path(q: "eagle", format: :json)
    assert_response :success
    names = response.parsed_body.map { |b| b["name"] }
    assert_includes names, "Eagle Rare 10"
  end

  test "bottle page shows score, reviews, and slug routing" do
    get bottle_path(bottles(:eagle_rare))
    assert_response :success
    assert_match "Eagle Rare 10", response.body
    assert_select "section span.font-semibold.text-cream", text: "4" # strip_insignificant_zeros: 4.0 -> "4"
    assert_match "Cherry and oak", response.body # the review feed
  end

  test "bottle page shows honest fractional average and doesn't lose a star glyph" do
    Review.create!(
      user: users(:jane),
      bottle: bottles(:eagle_rare),
      rating: 4.5,
      notes: "Baking spice, big vanilla."
    )

    get bottle_path(bottles(:eagle_rare))
    assert_response :success
    assert_match "4.25", response.body # true average of 4.0 and 4.5
    assert_select "span[aria-label=\"4.25 out of 5\"]", text: "★★★★½"
  end

  test "a review has its own page, publicly readable and linked from the feed" do
    review = reviews(:john_eagle_rare)
    get reviews_path
    assert_select "a[href=?]", review_path(review)

    get review_path(review)
    assert_response :success
    assert_match "Cherry and oak", response.body
    assert_match "Eagle Rare 10", response.body
  end

  test "flavor tags filter the tasting record" do
    get reviews_path(tags: "toffee,cherry")
    assert_response :success
    assert_match "Eagle Rare 10", response.body
    assert_match "tasting of toffee", response.body # active chip
    assert_no_match "Lagavulin 16", response.body   # no reviews at all

    get review_path(reviews(:john_eagle_rare))
    assert_select "a[href=?]", reviews_path(tags: "toffee"), text: "toffee"
  end

  test "distillery is a first-class filter and search group" do
    get reviews_path(distillery: "Buffalo Trace")
    assert_response :success
    assert_match "Eagle Rare 10", response.body
    assert_match "from Buffalo Trace", response.body # active chip
    assert_no_match "Lagavulin 16", response.body

    get search_reviews_path(q: "buffalo", format: :json)
    labels = response.parsed_body["distilleries"].map { |d| d["label"] }
    assert_includes labels, "Buffalo Trace — Distillery"

    get bottle_path(bottles(:eagle_rare))
    assert_select "a[href=?]", reviews_path(distillery: "Buffalo Trace"), text: "Buffalo Trace"
  end

  test "bottle page draws the community flavor wave with clickable families" do
    get bottle_path(bottles(:eagle_rare)) # john's fields: toffee/cherry/oak/leather...
    assert_response :success
    assert_match "Flavor profile", response.body
    assert_select "a[href=?] text", reviews_path(tags: "sweet")
  end

  test "unknown slug 404s" do
    get bottle_path(id: "not-a-bottle")
    assert_response :not_found
  end
end
