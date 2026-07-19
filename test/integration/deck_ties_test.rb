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

  # Pours save with the deck now: one form, one Save button, nested rows.
  def save_deck(pours)
    patch admin_presentation_path(@deck), params: {
      presentation: { title: @deck.title, content: @deck.content, price: @deck.price,
                      presentation_bottles_attributes: pours }
    }
  end

  test "an admin adds a catalog-linked pour by saving the deck" do
    sign_in @admin
    assert_difference "PresentationBottle.count", 1 do
      save_deck({ "0" => { bottle_id: @bottle.id, label: "the opener", position: 1 } })
    end
    pour = @deck.reload.presentation_bottles.first
    assert_equal @bottle, pour.bottle
    assert_predicate pour, :linked?
  end

  # A cocktail has no catalog bottle, and losing that was the whole reason the
  # old freeform field couldn't simply be deleted.
  test "an admin adds a free-text pour with no catalog bottle" do
    sign_in @admin
    assert_difference "PresentationBottle.count", 1 do
      save_deck({ "0" => { name: "Mint Julep", origin: "Kentucky, 1803", price: "$12",
                           notes: "Pour it for the Derby chapter.", position: 1 } })
    end
    pour = @deck.reload.presentation_bottles.first
    assert_equal "Mint Julep", pour.display_name
    assert_not pour.linked?
    assert_equal "Kentucky, 1803", pour.origin_text
    assert_equal "Pour it for the Derby chapter.", pour.notes
  end

  test "a pour with neither a bottle nor a name is dropped, not an error" do
    sign_in @admin
    assert_no_difference "PresentationBottle.count" do
      save_deck({ "0" => { name: "", bottle_id: "", position: 1 } })
    end
    assert_redirected_to admin_presentation_path(@deck)
  end

  test "the same bottle cannot be linked twice" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    duplicate = @deck.presentation_bottles.new(bottle: @bottle, position: 2)
    assert_not duplicate.valid?
    assert_match "already on this deck's pour list", duplicate.errors.full_messages.join
  end

  test "an admin removes a pour by saving the deck" do
    pour = PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    sign_in @admin
    assert_difference "PresentationBottle.count", -1 do
      save_deck({ "0" => { id: pour.id, _destroy: "1" } })
    end
  end

  test "a non-admin cannot touch the pour list" do
    sign_in users(:jane)
    assert_no_difference "PresentationBottle.count" do
      save_deck({ "0" => { bottle_id: @bottle.id, position: 1 } })
    end
  end

  test "the admin form edits the pour list inline, with no second section" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    sign_in @admin
    get edit_admin_presentation_path(@deck)
    assert_response :success

    assert_match "presentation[presentation_bottles_attributes]", response.body,
                 "pours must be nested fields on the deck form"
    assert_equal 1, response.body.scan("· The pour list").size,
                 "the admin must show one pour list section, not two"
    assert_no_match "whiskey_recommendations", response.body,
                    "the legacy pour field must be gone from the form"
  end

  # There is one name box: picking a suggestion submits the bottle's name in it.
  # A linked row must not keep that copy, or renaming the bottle would leave
  # every deck showing the old name.
  test "a linked pour lets the catalog own the name" do
    sign_in @admin
    save_deck({ "0" => { bottle_id: @bottle.id, name: "Tied Dram", position: 1 } })

    pour = @deck.reload.presentation_bottles.sole
    assert_nil pour.name, "the name column is only for pours with no catalog bottle"
    assert_equal "Tied Dram", pour.title, "the name still displays, via the catalog"

    @bottle.update!(name: "Renamed Dram")
    assert_equal "Renamed Dram", pour.reload.title, "a linked pour follows the catalog"
  end

  test "the pour form has one name box, wired to the catalog" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    sign_in @admin
    get edit_admin_presentation_path(@deck)

    assert_equal 1, response.body.scan('presentation_bottles_attributes][0][name]').size,
                 "name and catalog bottle are one field, not two"
    assert_match "data-bottle-search-name-field-value", response.body
    assert_match "Linked to #{@bottle.display_name}", response.body,
                 "the row must show whether it is linked, not imply it"
  end

  # The pour row's fields are per-DECK. The bottle's own page is the record of
  # the bottle, and nothing an admin types into a deck may leak back into it.
  test "editing a pour never writes back to the catalog bottle" do
    @bottle.update!(style: "Bourbon", region: "Kentucky", distillery: "Buffalo Trace")
    before = @bottle.attributes
    sign_in @admin
    save_deck({ "0" => { bottle_id: @bottle.id, position: 1,
                         origin: "Somewhere else entirely", style: "Rewritten for this deck",
                         price: "$999", notes: "The deck author's own words." } })

    pour = @deck.reload.presentation_bottles.sole
    assert_equal "Rewritten for this deck", pour.style_text
    assert_equal "$999", pour.price
    assert_equal before, @bottle.reload.attributes, "the bottle record must be untouched"
  end

  test "a bottle's suggestions never render as the deck's own price or notes" do
    # Facts about the bottle (origin, style) may fall back at render time.
    # Market data and opinion may not: they are prefill-only, so an unread
    # suggestion can't appear on a deck page as the author's word.
    @bottle.update!(style: "Bourbon")
    Review.new(user: users(:jane), bottle: @bottle, rating: 4.0, nose: "pear", palate: "oak",
               price_paid: 50).save!(validate: false)
    pour = PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)

    assert_equal "Bourbon", pour.style_text, "style is a fact about the bottle"
    assert_nil pour.price, "price is prefilled at authoring time, never inferred at render"
    assert_nil pour.notes, "tasting notes are the author's, never borrowed silently"
  end

  # The pour form prefills origin and style from the catalog, so the payload
  # the search endpoint returns is load-bearing, not decorative.
  test "bottle search returns the fields a pour row prefills from" do
    @bottle.update!(distillery: "Buffalo Trace", region: "Kentucky", style: "Bourbon")
    sign_in @admin
    get search_bottles_path(q: "Tied")
    assert_response :success

    match = JSON.parse(response.body).find { |b| b["id"] == @bottle.id }
    assert_equal "Buffalo Trace, Kentucky", match["origin"]
    assert_equal "Bourbon", match["style"]
  end

  # Descriptors come from the structured tasting sections, not the free notes
  # field, so that is what a suggestion can be built from.
  test "bottle search suggests a price and notes once there are tastings" do
    Review.new(user: users(:jane), bottle: @bottle, rating: 4.0, nose: "pear", palate: "oak",
               notes: "Lovely.", price_paid: 50).save!(validate: false)
    sign_in @admin
    get search_bottles_path(q: "Tied")

    match = JSON.parse(response.body).find { |b| b["id"] == @bottle.id }
    assert_equal "$50", match["price"]
    assert match["notes"].present?, "descriptors tasters actually used"
  end

  test "an untasted bottle suggests nothing rather than inventing it" do
    sign_in @admin
    get search_bottles_path(q: "Tied")

    match = JSON.parse(response.body).find { |b| b["id"] == @bottle.id }
    assert_nil match["price"]
    assert_nil match["notes"]
  end

  test "the pour form marks the fields the catalog can prefill" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    sign_in @admin
    get edit_admin_presentation_path(@deck)
    assert_match 'data-bottle-fill="origin"', response.body
    assert_match 'data-bottle-fill="style"', response.body
    assert_match 'data-controller="bottle-search"', response.body
  end

  test "a linked pour makes the whole card the link, with no nested anchors" do
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1, notes: "Pear and oak.")
    get presentation_path(@deck)
    assert_response :success

    card = css_select("a[href='#{bottle_path(@bottle)}']").find { |a| a.css("h3").any? }
    assert card, "the pour card itself must be the link, not just its title"
    assert_equal 0, card.css("a").size, "a nested anchor is invalid and steals the click"
    assert_match "Pear and oak.", card.to_s, "the whole card, notes included, is inside the link"
  end

  # display_name appends the distillery; the card prints origin separately, so
  # using it there printed the distillery twice.
  test "a pour card titles the bottle without repeating its origin" do
    @bottle.update!(distillery: "Hikari Distillery, Fukuoka")
    PresentationBottle.create!(presentation: @deck, bottle: @bottle, position: 1)
    get presentation_path(@deck)

    card = css_select("a[href='#{bottle_path(@bottle)}']").find { |a| a.css("h3").any? }
    assert_equal "Tied Dram", card.css("h3").text.strip
    assert_equal 1, card.to_s.scan("Hikari Distillery, Fukuoka").size
  end

  test "an unlinked pour is not a link" do
    PresentationBottle.create!(presentation: @deck, name: "Mint Julep", position: 1)
    get presentation_path(@deck)
    assert_match "Mint Julep", response.body
    assert_empty css_select("a").select { |a| a.text.include?("Mint Julep") },
                 "a pour with no catalog bottle has nowhere to link to"
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

# The written pour cards were migrated onto presentation_bottles. This pins the
# conversion rules, because the legacy column is the only copy of that content
# until it's dropped.
class WrittenPourMigrationTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    require Rails.root.join("db/migrate/20260719140100_migrate_written_pours_into_the_pour_list.rb").to_s
  end

  def deck_with(written)
    deck = Presentation.create!(author: @admin, title: "Legacy #{Presentation.count}", content: "x", price: 5)
    deck.update_column(:whiskey_recommendations, written)
    deck
  end

  def migrate!
    MigrateWrittenPoursIntoThePourList.new.tap { |m| m.verbose = false }.up
  end

  test "a written card becomes a free-text pour, keeping every field" do
    deck = deck_with("Mint Julep|Kentucky, 1803|$12|Bourbon and mint|Pour it for the Derby chapter.")
    migrate!

    pour = deck.reload.presentation_bottles.sole
    assert_equal "Mint Julep", pour.display_name
    assert_not pour.linked?, "no catalog bottle by that name, so it stays text"
    assert_equal "Kentucky, 1803", pour.origin
    assert_equal "$12", pour.price
    assert_equal "Bourbon and mint", pour.style
    assert_equal "Pour it for the Derby chapter.", pour.notes
  end

  test "a written card matching a catalog bottle is linked to it" do
    bottle = Bottle.create!(name: "Glenfiddich 12", created_by: @admin)
    deck = deck_with("glenfiddich 12|Speyside|$45|Light and fruity|Pear and oak.")
    migrate!

    pour = deck.reload.presentation_bottles.sole
    assert_equal bottle, pour.bottle, "matching is case-insensitive"
    assert_equal "Pear and oak.", pour.notes, "the author's own notes survive the link"
  end

  test "order is preserved" do
    deck = deck_with("First|a|$1|s|n\nSecond|a|$2|s|n\nThird|a|$3|s|n")
    migrate!
    assert_equal %w[First Second Third], deck.reload.presentation_bottles.ordered.map(&:display_name)
  end

  test "a deck that already has a pour list is left alone" do
    deck = deck_with("Written|a|$1|s|n")
    existing = PresentationBottle.create!(presentation: deck, name: "Already here", position: 1)
    migrate!
    assert_equal [ existing ], deck.reload.presentation_bottles.to_a
  end

  test "running it twice does not duplicate a pour list" do
    deck = deck_with("Only One|a|$1|s|n")
    migrate!
    migrate!
    assert_equal 1, deck.reload.presentation_bottles.count
  end
end
