require "test_helper"

# Society verdict cards on bottle pages: the room's collective take shaped
# like a tasting card (aggregate score + most common tasting words), linking
# to a verdict page with every individual card.
class SocietyVerdictTest < ActionDispatch::IntegrationTest
  test "bottle page leads with the public society's verdict card" do
    bottle = bottles(:ardbeg_10)
    get bottle_path(bottle)
    assert_response :success

    assert_match "Society verdict", response.body
    assert_select "article a", text: societies(:single_malt).name

    # Aggregate score present.
    event_reviews = bottle.reviews.joins(:event).where(events: { society_id: societies(:single_malt).id })
    mean = (event_reviews.sum(:rating) / event_reviews.count).round(2)
    assert_match ActionController::Base.helpers.number_with_precision(mean, precision: 2, strip_insignificant_zeros: true), response.body

    # Drill-in link to the verdict page.
    assert_select "a[href=?]", verdict_bottle_path(bottle, society_id: societies(:single_malt).id), text: /Read the tastings/
  end

  test "verdict card shows the room's most common tasting words" do
    bottle = bottles(:ardbeg_10)
    # Two members mention peat on the nose; one mentions pear. Peat wins.
    reviews(:john_spring_ardbeg).update_columns(nose: "Peat smoke, iodine, pear")
    reviews(:seth_spring_ardbeg).update_columns(nose: "Peat and brine")

    get bottle_path(bottle)
    assert_response :success
    assert_select "dt", text: "Nose"
    assert_match "Peat", response.body
  end

  test "common_descriptors counts each review's word once and ranks by frequency" do
    reviews = [
      Review.new(nose: "peat peat peat, pear"),
      Review.new(nose: "peat and iodine"),
      Review.new(nose: "iodine again")
    ]
    result = Review.common_descriptors(reviews)
    # peat: 2 reviews (triple mention counts once), iodine: 2, pear: 1
    assert_equal %w[iodine pear peat], result["Nose"].sort
    assert_equal %w[iodine peat pear], result["Nose"], "ties alphabetical, then by frequency"
  end

  test "verdict page lists every individual tasting card" do
    bottle = bottles(:ardbeg_10)
    society = societies(:single_malt)

    get verdict_bottle_path(bottle, society_id: society.id)
    assert_response :success

    assert_select "h1 a", text: society.name
    assert_select "h1 a", text: bottle.name
    # Individual cards with profile links.
    bottle.reviews.joins(:event).where(events: { society_id: society.id }).each do |review|
      assert_select "a[href=?]", profile_path(review.user)
    end
    assert_select "a", text: /Read the full tasting/
  end

  test "private societies 404 on the verdict page and never get a card" do
    bottle = bottles(:four_roses_sb)
    private_society = societies(:bourbon_club)
    assert private_society.private?

    get bottle_path(bottle)
    assert_response :success
    assert_select "article a", text: societies(:single_malt).name
    assert_no_match private_society.name, response.body

    get verdict_bottle_path(bottle, society_id: private_society.id)
    assert_response :not_found
  end

  test "Bottle#society_verdicts uses latest-per-member math" do
    bottle = bottles(:ardbeg_10)
    verdicts = bottle.society_verdicts.to_a
    single_malt = verdicts.find { |s| s.id == societies(:single_malt).id }
    assert single_malt, "single_malt should have a verdict"

    # John re-tastes lower at a later event of the same society: his newer
    # score replaces the old one instead of double-counting him.
    # save(validate: false): the event-review guards (pour list, RSVP,
    # reveal) are out of scope — this test pins the aggregate SQL only.
    old_reviewers = single_malt.verdict_reviewers
    Review.new(user: users(:john), bottle: bottle, event: events(:mystery_flight), rating: 1.0, notes: "Off night.").save(validate: false)
    fresh = bottle.society_verdicts.to_a.find { |s| s.id == societies(:single_malt).id }
    assert_equal old_reviewers, fresh.verdict_reviewers, "reviewer count must not grow on a re-taste"
    assert fresh.verdict_avg.to_f < single_malt.verdict_avg.to_f, "newer low score should pull the average down"
  end
end
