require "test_helper"

# The homepage's featured deck and the review its tasting record leads with
# (HomepageFeature): an admin-featured deck when there is one, otherwise the
# three best-selling published decks in turn, a day each, every deck with a
# review of a bottle of its own.
class HomepageFeatureTest < ActiveSupport::TestCase
  DAY = Date.new(2026, 11, 23)

  setup do
    Review.destroy_all
    @n = 0
  end

  def deck(title, slides: 1, published: true, at: nil, price: 9.99)
    @n += 1
    deck = Presentation.create!(author: users(:admin), title: (title.size < 2 ? "Deck #{title}" : title), content: "A story.", price: price)
    at ||= @n.minutes.ago
    deck.update_columns(published: published, created_at: at, updated_at: at)
    slides.times { |i| deck.slide_images.attach(io: File.open(file_fixture("sample_review.jpg")), filename: "s#{i}.jpg", content_type: "image/jpeg") }
    deck
  end

  def buyer(admin_role: :none)
    @n += 1
    User.create!(email: "hf#{@n}-#{SecureRandom.hex(3)}@example.com", password: "password123",
                 first_name: "Buyer", last_name: "No#{@n}", admin_role: admin_role)
  end

  def sell(deck, type: "direct", price: 9.99, to: buyer)
    UserPresentation.create!(user: to, presentation: deck, purchase_type: type, purchase_price: price, purchased_at: Time.current)
  end

  def bottle(name)
    Bottle.create!(name: name, distillery: "Test Distillery")
  end

  def review(bottle, event: nil, wheel: true, at: nil, by: buyer)
    @n += 1
    r = Review.new(user: by, bottle: bottle, event: event, rating: 4.0, notes: "Real notes.",
                   flavor_wheel: wheel ? { "smoky" => 0.5 } : {})
    r.save!(validate: false)
    r.update_columns(created_at: at || @n.minutes.from_now)
    r
  end

  def feature(day: DAY, slot: nil)
    HomepageFeature.new(day: day, slot: slot)
  end

  # ── Which deck ────────────────────────────────────────────────────────────

  test "an admin-featured deck always wins, whatever sells" do
    seller = deck("Best Seller")
    3.times { sell(seller) }
    featured = deck("Featured Deck")
    featured.update_column(:featured, true)

    3.times do |i|
      f = feature(day: DAY + i)
      assert_equal featured, f.deck
      assert_equal :featured, f.source
      assert_equal [ featured ], f.decks
    end
  end

  test "with none featured, the candidates are the three best sellers, most sold first" do
    one = deck("One Sale")
    three = deck("Three Sales")
    two = deck("Two Sales")
    none = deck("No Sales")
    sell(one)
    3.times { sell(three) }
    2.times { sell(two) }

    f = feature
    assert_equal :rotation, f.source
    assert_equal [ three, two, one ], f.decks
    assert_not_includes f.decks, none
  end

  test "a sale is a paid purchase or a credit unlock; free claims and admins' copies do not count" do
    paid = deck("Paid Deck", at: 5.days.ago)
    credit = deck("Credit Deck", at: 4.days.ago)
    claimed = deck("Free Claims", at: 3.days.ago, price: 0)
    staff = deck("Staff Copies", at: 2.days.ago)
    filler = deck("Newest Filler", at: 1.day.ago)
    sell(paid)
    2.times { sell(credit, type: "credit", price: nil) }
    4.times { sell(claimed, price: 0) }
    3.times { sell(staff, to: buyer(admin_role: :full)) }
    sell(staff, to: buyer(admin_role: :limited))

    f = feature
    assert_equal [ credit, paid, filler ], f.decks, "then the newest deck fills the third place"
    assert_equal({ credit.id => 2, paid.id => 1, filler.id => 0 }, f.sales)
  end

  test "ties go to the newer deck" do
    older = deck("Older", at: 3.days.ago)
    newer = deck("Newer", at: 1.day.ago)
    middle = deck("Middle", at: 2.days.ago)
    [ older, newer, middle ].each { |d| sell(d) }
    assert_equal [ newer, middle, older ], feature.decks
  end

  test "with fewer than three sellers the newest other decks fill the places; with no sales at all it is the three newest" do
    old = deck("Old", at: 4.days.ago)
    mid = deck("Mid", at: 3.days.ago)
    seller = deck("Seller", at: 5.days.ago)
    new = deck("New", at: 1.day.ago)
    assert_equal [ new, mid, old ], feature.decks

    sell(seller)
    assert_equal [ seller, new, mid ], feature.decks
  end

  test "only published decks with rendered slides can be featured this way" do
    draft = deck("Draft", published: false)
    bare = deck("No Slides", slides: 0)
    [ draft, bare ].each { |d| 2.times { sell(d) } }
    live = deck("Live")
    assert_equal [ live ], feature.decks
    assert_equal live, feature.deck
  end

  test "with no deck to show there is none, and no error" do
    f = feature
    assert_nil f.deck
    assert_equal :none, f.source
    assert_equal [], f.decks
    assert_nil f.review
    assert_equal [], f.record_reviews
  end

  # ── The rotation ──────────────────────────────────────────────────────────

  test "the featured deck is the same all day and steps to the next seller each day" do
    decks = [ deck("A", at: 1.day.ago), deck("B", at: 2.days.ago), deck("C", at: 3.days.ago) ]
    assert_equal feature(day: DAY).deck, feature(day: DAY).deck
    week = (0...6).map { |i| feature(day: DAY + i).deck }
    assert_equal decks.sort_by(&:id), week.first(3).sort_by(&:id), "three days show all three"
    assert_equal week.first(3), week.last(3), "then round again"
    start = decks.index(week.first)
    assert_equal decks.rotate(start), week.first(3), "in selling order"
  end

  test "two decks take alternate days; one deck is always it" do
    a = deck("A", at: 1.day.ago)
    assert_equal [ a, a ], [ feature(day: DAY).deck, feature(day: DAY + 1).deck ]
    b = deck("B", at: 2.days.ago)
    assert_equal [ a, b ].sort_by(&:id), [ feature(day: DAY).deck, feature(day: DAY + 1).deck ].sort_by(&:id)
  end

  test "a slot can be asked for by number, for previewing each of the three" do
    decks = [ deck("A", at: 1.day.ago), deck("B", at: 2.days.ago), deck("C", at: 3.days.ago) ]
    assert_equal decks, [ 1, 2, 3 ].map { |s| feature(slot: s).deck }
    assert_equal feature.deck, feature(slot: 9).deck, "a slot that does not exist is ignored"
    assert_equal feature.deck, feature(slot: 0).deck
  end

  # ── The review ────────────────────────────────────────────────────────────

  test "a deck's review bottle gives the record its review" do
    a = deck("A", at: 1.day.ago)
    weller = bottle("Weller")
    other = bottle("Something Newer")
    chosen = review(weller)
    review(other)
    a.update!(record_bottle: weller)

    f = feature
    assert_equal chosen, f.review
    assert_equal :chosen, f.review_source
  end

  test "the newest review of the bottle that can draw a wheel is preferred, else the newest" do
    a = deck("A")
    weller = bottle("Weller")
    wheel = review(weller, wheel: true, at: 3.days.ago)
    review(weller, wheel: false, at: 1.day.ago)
    a.update!(record_bottle: weller)
    assert_equal wheel, feature.review

    wheel.destroy
    assert_equal false, feature.review.wheel_display_profile.any?
  end

  test "only reviews allowed on the homepage count: nothing from a private or still-secret night" do
    a = deck("A")
    weller = bottle("Weller")
    review(weller, event: events(:allocated_night))
    secret = events(:mystery_flight)
    review(weller, event: secret)
    a.update!(record_bottle: weller)

    f = feature
    assert_nil f.review
    assert_equal :none, f.review_source

    open = review(weller, event: events(:spring_blind))
    assert_equal open, feature.review
  end

  test "without a review bottle, the deck's pour list gives one: its first linked bottle with a public review" do
    a = deck("A")
    unreviewed = bottle("Unreviewed Pour")
    poured = bottle("Reviewed Pour")
    a.presentation_bottles.create!(bottle: unreviewed)
    a.presentation_bottles.create!(name: "A cocktail")
    a.presentation_bottles.create!(bottle: poured)
    mine = review(poured, at: 5.days.ago)
    review(bottle("Newest Anywhere"))

    f = feature
    assert_equal mine, f.review
    assert_equal :pour_list, f.review_source
  end

  test "with neither, the record is the newest public review, as before" do
    deck("A")
    older = review(bottle("Older"), at: 2.days.ago)
    newest = review(bottle("Newest"), at: 1.day.ago)
    f = feature
    assert_equal newest, f.review
    assert_equal :newest, f.review_source
    assert_equal [ newest, older ], f.record_reviews
  end

  test "the three decks never lead with the same bottle" do
    a = deck("A", at: 1.day.ago)
    b = deck("B", at: 2.days.ago)
    c = deck("C", at: 3.days.ago)
    shared = bottle("On Two Pour Lists")
    own = bottle("B's Own")
    spare = bottle("Spare")
    # A has no bottle of its own; B chose one; C's pour list shares A's bottle.
    a.presentation_bottles.create!(bottle: shared)
    c.presentation_bottles.create!(bottle: shared)
    b.update!(record_bottle: own)
    review(shared)
    review(own)
    review(spare, at: 9.days.ago)

    leads = [ 1, 2, 3 ].map { |s| feature(slot: s).review.bottle }
    assert_equal [ shared, own, spare ], leads
    assert_equal [ :pour_list, :chosen, :newest ], [ 1, 2, 3 ].map { |s| feature(slot: s).review_source }
  end

  test "a chosen bottle is kept for its deck: another deck's pour list cannot take it" do
    a = deck("A", at: 1.day.ago)
    b = deck("B", at: 2.days.ago)
    weller = bottle("Weller")
    a.presentation_bottles.create!(bottle: weller)
    b.update!(record_bottle: weller)
    only = review(weller)

    assert_equal only, feature(slot: 2).review
    assert_equal :chosen, feature(slot: 2).review_source
    assert_equal only, feature(slot: 1).review, "with one review in the whole record, it repeats rather than show nothing"
    assert_equal :repeat, feature(slot: 1).review_source
  end

  test "the record's rows never list a bottle another of the three leads with" do
    a = deck("A", at: 1.day.ago)
    b = deck("B", at: 2.days.ago)
    for_a = bottle("A's Bottle")
    for_b = bottle("B's Bottle")
    a.update!(record_bottle: for_a)
    b.update!(record_bottle: for_b)
    lead = review(for_a, at: 9.days.ago)
    review(for_b, at: 1.day.ago)
    x = review(bottle("X"), at: 2.days.ago)
    y = review(bottle("Y"), at: 3.days.ago)

    assert_equal [ lead, x, y ], feature(slot: 1).record_reviews
    assert_equal [ for_b ], feature(slot: 2).record_reviews.first(1).map(&:bottle)
    assert_not_includes feature(slot: 2).record_reviews.map(&:bottle), for_a
  end

  test "two decks cannot be given the same review bottle" do
    a = deck("A")
    b = deck("B")
    weller = bottle("Weller")
    a.update!(record_bottle: weller)
    b.record_bottle = weller
    assert_not b.valid?
    assert_includes b.errors[:record_bottle_id].join, "already"
  end
end
