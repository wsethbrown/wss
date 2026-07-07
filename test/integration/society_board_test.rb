require "test_helper"

class SocietyBoardTest < ActionDispatch::IntegrationTest
  test "society page ranks bottles by the society's event-review mean" do
    get society_path(societies(:single_malt))
    assert_response :success
    assert_match "The review board", response.body
    body = response.body
    # Ardbeg 4.25 (2 reviewers) > Four Roses 4.0 (1) > GlenDronach 3.25 (2)
    assert_operator body.index("Ardbeg 10"), :<, body.index("Four Roses Small Batch")
    assert_operator body.index("Four Roses Small Batch"), :<, body.index("GlenDronach 12")
    assert_match "2 reviewers", body
    assert_select "a[href=?]", bottle_path(bottles(:ardbeg_10))
  end

  test "board rows expand to member reviews" do
    get society_path(societies(:single_malt))
    assert_match "Member reviews", response.body
    assert_match "Campfire in a glass", response.body
  end

  test "solo reviews and other societies' nights never reach the board" do
    get society_path(societies(:single_malt))
    assert_no_match "Eagle Rare 10", response.body                     # solo-only bottle
    assert_no_match "Even better from a private stash", response.body  # the private club's review

    get society_path(societies(:whiskey_lovers))
    assert_no_match "The review board", response.body # no event reviews at all
  end

  test "the private club's board stays behind the existing society policy" do
    get society_path(societies(:bourbon_club))
    assert_redirected_to societies_url # outsiders never see the page at all

    sign_in users(:jane)
    get society_path(societies(:bourbon_club))
    assert_response :success
    assert_match "The review board", response.body
    assert_match "Even better from a private stash", response.body
  end
end
