require "test_helper"

class ReviewProvenanceTest < ActionDispatch::IntegrationTest
  test "bottle page links public-society event reviews to the event" do
    get bottle_path(bottles(:ardbeg_10))
    assert_response :success
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind)) do
      assert_select "span", text: "The Spring Blind Flight"
      assert_select "span", text: "Single Malt Appreciation"
      assert_select "span", text: "3 pours"
    end
  end

  test "bottle page veils private-society events behind an unlinked card with no society name" do
    get bottle_path(bottles(:four_roses_sb))
    assert_response :success
    assert_match "A private society", response.body # jane's private-club night
    assert_match "Allocated Bottles Night", response.body # event title still shows
    assert_no_match "Exclusive Bourbon Club", response.body # society name never appears
    assert_no_match society_event_path(societies(:bourbon_club), events(:allocated_night)), response.body
    # …while john's public-society review of the same bottle still links out.
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind))
  end

  test "solo reviews carry no provenance" do
    get bottle_path(bottles(:eagle_rare))
    assert_response :success
    assert_no_match "A private society", response.body
    assert_select "a[href*=?]", "/events/", count: 0
  end

  test "the reviews feed shows a non-link provenance line under recent tastings, not a nested link" do
    get reviews_path
    assert_response :success
    # The feed card is itself a link to the review; a nested <a> to the event
    # would be invalid HTML, so provenance here is plain text, not a link.
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind)), count: 0
    assert_match "The Spring Blind Flight", response.body
    assert_match "A private society", response.body # jane's veiled review, same feed
  end

  test "profile tastings veil private societies but link public events" do
    sign_in users(:john)
    get profile_path(users(:jane)) # jane's only tasting is at the private club
    assert_match "A private society", response.body
    assert_no_match "Exclusive Bourbon Club", response.body
    assert_match "Allocated Bottles Night", response.body

    get profile_path(users(:john))
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind))
  end

  test "review's own page renders the event card for a public society's event" do
    get review_path(reviews(:john_spring_ardbeg))
    assert_response :success
    assert_select "a[href=?]", society_event_path(societies(:single_malt), events(:spring_blind)) do
      assert_select "span", text: "The Spring Blind Flight"
      assert_select "span", text: "Single Malt Appreciation"
    end
  end

  test "review's own page veils a private society's event: title shows, society and link do not" do
    get review_path(reviews(:jane_allocated_four_roses))
    assert_response :success
    assert_match "Allocated Bottles Night", response.body
    assert_no_match "Exclusive Bourbon Club", response.body
    assert_select "a[href=?]", society_event_path(societies(:bourbon_club), events(:allocated_night)), count: 0
    assert_match "A private society", response.body
  end
end
