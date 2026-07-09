require "test_helper"

# Society verdict cards on bottle pages: the room's collective take leads
# the Tastings list, expandable to the individual event reviews.
class SocietyVerdictTest < ActionDispatch::IntegrationTest
  test "bottle page leads with the public society's verdict card" do
    bottle = bottles(:ardbeg_10)
    get bottle_path(bottle)
    assert_response :success

    assert_match "Society verdict", response.body
    assert_select "article a", text: societies(:single_malt).name

    # Aggregate math: latest event review per member at this society.
    event_reviews = bottle.reviews.joins(:event).where(events: { society_id: societies(:single_malt).id })
    mean = (event_reviews.sum(:rating) / event_reviews.count).round(2)
    assert_match ActionController::Base.helpers.number_with_precision(mean, precision: 2, strip_insignificant_zeros: true), response.body

    # Drill-down: individual pours with profile links.
    assert_select "details summary", text: "The individual pours"
    assert_select "details a[href=?]", profile_path(users(:john))
  end

  test "private societies never get a verdict card" do
    bottle = bottles(:four_roses_sb)
    assert reviews(:jane_allocated_four_roses).event.society.private?

    get bottle_path(bottle)
    assert_response :success

    # single_malt (public) reviewed it at spring_blind — verdict shows.
    assert_select "article a", text: societies(:single_malt).name
    # bourbon_club (private) also poured it — never named.
    assert_no_match societies(:bourbon_club).name, response.body
  end

  test "Bottle#society_verdicts uses latest-per-member math" do
    bottle = bottles(:ardbeg_10)
    verdicts = bottle.society_verdicts.to_a
    single_malt = verdicts.find { |s| s.id == societies(:single_malt).id }
    assert single_malt, "single_malt should have a verdict"

    # John re-tastes lower at a later event of the same society: his newer
    # score replaces the old one instead of double-counting him.
    old_reviewers = single_malt.verdict_reviewers
    # save(validate: false): the event-review guards (pour list, RSVP,
    # reveal) are out of scope — this test pins the aggregate SQL only.
    Review.new(user: users(:john), bottle: bottle, event: events(:mystery_flight), rating: 1.0, notes: "Off night.").save(validate: false)
    fresh = bottle.society_verdicts.to_a.find { |s| s.id == societies(:single_malt).id }
    assert_equal old_reviewers, fresh.verdict_reviewers, "reviewer count must not grow on a re-taste"
    assert fresh.verdict_avg.to_f < single_malt.verdict_avg.to_f, "newer low score should pull the average down"
  end
end
