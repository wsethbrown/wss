require "test_helper"

# The demo chain the fixtures guarantee end-to-end: a review's event card
# leads to the event page (everything rated that night, including the
# arriving reviewer's other scores), and the same night ranks the society's
# review board. If this breaks, the Phase-2 story is broken.
class ReviewDemoChainTest < ActionDispatch::IntegrationTest
  test "event card leads to an event page showing everything rated that night" do
    get bottle_path(bottles(:ardbeg_10))
    event_url = society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]", event_url

    get event_url
    assert_response :success
    [bottles(:ardbeg_10), bottles(:glendronach_12), bottles(:four_roses_sb)].each do |bottle|
      assert_select "a[href=?]", bottle_path(bottle)
    end
    assert_match "Campfire in a glass", response.body # seth's other score, one click from his review
  end

  test "the same night ranks the society's review board" do
    get society_event_path(societies(:single_malt), events(:spring_blind))
    assert_select "a[href=?]", society_path(societies(:single_malt))

    get society_path(societies(:single_malt))
    assert_match "The review board", response.body
    assert_match "4.25", response.body
  end
end
