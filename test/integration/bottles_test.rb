require "test_helper"

class BottlesTest < ActionDispatch::IntegrationTest
  test "index lists bottles and recent reviews, signed out" do
    get bottles_path
    assert_response :success
    assert_select "h1", text: /The bottle library/i
    assert_match "Eagle Rare 10", response.body
    assert_match "Cherry and oak", response.body # recent review feed
  end

  test "index filters by search term" do
    get bottles_path(q: "lagavulin")
    assert_response :success
    assert_match "Lagavulin 16", response.body
    assert_no_match "Eagle Rare 10", response.body
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
    assert_match "4.0", response.body            # aggregate from the one fixture review
    assert_match "Cherry and oak", response.body # the review feed
  end

  test "unknown slug 404s" do
    get bottle_path(id: "not-a-bottle")
    assert_response :not_found
  end
end
