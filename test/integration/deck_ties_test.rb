require "test_helper"

# Phase 3 "deck ties": a deck's pour list points at real catalog bottles, so
# the deck can show what rooms scored them and a bottle can name the decks
# that call for it. Plus deck names on review provenance.
class DeckPourLinksTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @deck = Presentation.create!(author: @admin, title: "Tie Deck", content: "A story.", price: 9.99)
    @deck.update_column(:published, true)
    @bottle = Bottle.create!(name: "Tied Dram", distillery: "Somewhere", created_by: @admin)
  end

  test "an admin links a bottle to a deck's pour list" do
    sign_in @admin
    assert_difference "PresentationBottle.count", 1 do
      post admin_presentation_presentation_bottles_path(@deck),
           params: { presentation_bottle: { bottle_id: @bottle.id, label: "the opener" } }
    end
    assert_equal [@bottle], @deck.reload.bottles.to_a
  end

  test "the same bottle cannot be linked twice" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    sign_in @admin
    assert_no_difference "PresentationBottle.count" do
      post admin_presentation_presentation_bottles_path(@deck), params: { presentation_bottle: { bottle_id: @bottle.id } }
    end
  end

  test "picking no bottle is refused with a usable message" do
    sign_in @admin
    assert_no_difference "PresentationBottle.count" do
      post admin_presentation_presentation_bottles_path(@deck), params: { presentation_bottle: { bottle_id: "" } }
    end
    assert_match "Pick a bottle", flash[:alert]
  end

  test "a non-admin cannot touch the pour list" do
    sign_in users(:jane)
    assert_no_difference "PresentationBottle.count" do
      post admin_presentation_presentation_bottles_path(@deck), params: { presentation_bottle: { bottle_id: @bottle.id } }
    end
  end

  test "an admin unlinks a pour" do
    pour = PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    sign_in @admin
    assert_difference "PresentationBottle.count", -1 do
      delete admin_presentation_presentation_bottle_path(@deck, pour)
    end
  end

  test "the deck page shows its linked pours" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1, label: "the opener")
    get presentation_path(@deck)
    assert_response :success
    assert_match "What this deck calls for", response.body
    assert_match "Tied Dram", response.body
  end

  # A deck's list is what it RECOMMENDS; a society pours what it can get.
  # These must never be presented as the same fact (owner directive).
  test "a deck with a pour list but no nights claims nothing about tastings" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    get presentation_path(@deck)
    assert_no_match "What societies actually poured", response.body
    assert_empty @deck.pours_from_nights
  end

  test "a bottle's overall score is labelled as overall, not as this deck's nights" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    Review.new(user: users(:jane), bottle: @bottle, rating: 5.0, notes: "Solo pour").save!(validate: false)
    get presentation_path(@deck)
    assert_match "overall rating", response.body
    assert_no_match "on these nights", response.body,
                    "a solo review must never read as a score from a night that ran this deck"
  end

  test "the bottle page names the decks that pour it, published only" do
    draft = Presentation.create!(author: @admin, title: "Draft Deck", content: "x", price: 1)
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    PresentationBottle.create!(presentation: draft, bottle: @bottle, position: 1)
    get bottle_path(@bottle)
    assert_response :success
    assert_match "Tie Deck", response.body
    assert_no_match "Draft Deck", response.body, "a draft deck must never surface on a public page"
  end

  test "a bottle with no decks shows no deck section" do
    get bottle_path(@bottle)
    assert_no_match "Poured in", response.body
  end
end

# What rooms POURED, as distinct from what the deck lists.
class DeckPouredOnNightsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @author = users(:john)
    @deck = Presentation.create!(author: @admin, title: "Poured Deck", content: "A story.", price: 9.99)
    @deck.update_column(:published, true)
    @listed = Bottle.create!(name: "Listed Dram", created_by: @admin)
    @swap = Bottle.create!(name: "Swapped Dram", created_by: @admin)
    PresentationBottle.create!(presentation: @deck, bottle: @listed, position: 1)
  end

  def finished_night(bottle, rating: nil)
    society = Society.create!(name: "Club #{Society.count}", description: "x", creator: @author, is_private: false)
    st = 2.days.ago
    event = Event.new(society: society, organizer: @author, title: "Night", description: "x",
                      location: "den", start_time: st, end_time: st + 2.hours, presentation: @deck)
    event.save!(validate: false)
    EventBottle.create!(event: event, bottle: bottle, position: 1)
    Review.new(user: @author, bottle: bottle, event: event, rating: rating, notes: "x").save!(validate: false) if rating
    event
  end

  test "a substituted bottle is surfaced and marked, not hidden" do
    finished_night(@swap, rating: 4.0)
    pours = @deck.pours_from_nights
    assert_equal [ @swap ], pours.map(&:bottle)
    refute pours.first.on_deck_list, "a bottle poured but not on the deck's list is a substitution"

    get presentation_path(@deck)
    assert_match "What societies actually poured", response.body
    assert_match "substituted", response.body
  end

  test "a bottle poured from the deck's own list is not marked a substitution" do
    finished_night(@listed, rating: 3.0)
    pour = @deck.pours_from_nights.first
    assert pour.on_deck_list
    get presentation_path(@deck)
    assert_no_match "substituted", response.body
  end

  test "scores count only reviews from nights that ran this deck" do
    finished_night(@listed, rating: 2.0)
    # A solo review, and a review from a night running a DIFFERENT deck, must
    # not leak into this deck's number.
    Review.new(user: users(:jane), bottle: @listed, rating: 5.0, notes: "solo").save!(validate: false)
    pour = @deck.pours_from_nights.first
    assert_equal 2.0, pour.average
    assert_equal 1, pour.reviews_count
  end

  test "a night that poured nothing yields no claims" do
    finished_night(@listed).event_bottles.destroy_all
    assert_empty @deck.pours_from_nights
  end

  test "an unfinished night does not count yet" do
    society = Society.create!(name: "Future Club", description: "x", creator: @author, is_private: false)
    event = Event.new(society: society, organizer: @author, title: "Upcoming", description: "x",
                      location: "den", start_time: 2.days.from_now, end_time: 3.days.from_now,
                      presentation: @deck)
    event.save!(validate: false)
    EventBottle.create!(event: event, bottle: @listed, position: 1)
    assert_empty @deck.pours_from_nights, "a night that hasn't happened can't have poured anything"
  end
end

# Deck names on review provenance, without breaking the private-society veil.
class DeckProvenanceTest < ActionDispatch::IntegrationTest
  setup do
    @author = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Provenance Deck", content: "x", price: 5)
    @deck.update_column(:published, true)
    @bottle = Bottle.create!(name: "Provenance Dram", created_by: @author)
  end

  def night(private_society:)
    society = Society.create!(name: private_society ? "Hidden Club" : "Open Club", description: "x",
                              creator: @author, is_private: private_society)
    st = 2.days.ago
    event = Event.new(society: society, organizer: @author, title: "Provenance Night", description: "x",
                      location: "den", start_time: st, end_time: st + 2.hours, presentation: @deck)
    event.save!(validate: false)
    EventBottle.create!(event: event, bottle: @bottle, position: 1)
    rsvp = EventRsvp.new(user: @author, event: event, status: "yes")
    rsvp.save!(validate: false)
    review = Review.new(user: @author, bottle: @bottle, event: event, rating: 4.0, notes: "Good pour")
    review.save!(validate: false)
    [society, event, review]
  end

  test "a public night names its deck on the bottle page" do
    night(private_society: false)
    get bottle_path(@bottle)
    assert_match "Provenance Deck", response.body
    assert_match "Open Club", response.body
  end

  test "a private night names the deck but still hides the society" do
    society, _event, _review = night(private_society: true)
    get bottle_path(@bottle)
    assert_match "Provenance Deck", response.body, "the deck is public catalog info"
    assert_no_match society.name, response.body, "the veil must still hide who gathered"
    assert_match "A private society", response.body
  end
end
