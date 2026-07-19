require "test_helper"

# Deck reviews (owner-approved). Eligibility: purchased the deck OR RSVP'd
# yes to a FINISHED event that ran it. Decks on events are optional.
class DeckReviewsTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = users(:john)
    @attendee = users(:jane)
    @stranger = users(:one)
    @society = Society.create!(name: "Deck Review Club", description: "x", creator: @organizer, is_private: false)
    SocietyMembership.create!(user: @attendee, society: @society, role: "member", status: "active")
    @deck = Presentation.create!(author: @organizer, title: "Reviewable Deck", content: "A story.", price: 9.99)
    @deck.update_column(:published, true)
    st = 2.days.ago
    @event = Event.new(society: @society, organizer: @organizer, title: "Deck Night",
                       description: "x", location: "den", start_time: st, end_time: st + 2.hours,
                       presentation: @deck)
    @event.save!(validate: false) # past event for the attendance path
    rsvp = EventRsvp.new(user: @attendee, event: @event, status: "yes")
    rsvp.save!(validate: false)
  end

  test "an attendee of a finished night can review the deck" do
    sign_in @attendee
    assert_difference "PresentationReview.count", 1 do
      post presentation_deck_reviews_path(@deck), params: { presentation_review: { rating: 4.5, body: "Great night" } }
    end
    assert_equal 4.5, @deck.presentation_reviews.last.rating.to_f
  end

  test "an owner can review the deck" do
    UserPresentation.create!(user: @stranger, presentation: @deck, purchase_type: "direct")
    sign_in @stranger
    assert_difference "PresentationReview.count", 1 do
      post presentation_deck_reviews_path(@deck), params: { presentation_review: { rating: 3.5 } }
    end
  end

  test "a stranger cannot review" do
    sign_in @stranger
    assert_no_difference "PresentationReview.count" do
      post presentation_deck_reviews_path(@deck), params: { presentation_review: { rating: 5.0 } }
    end
  end

  test "an upcoming-event RSVP does not qualify" do
    future = Event.create!(society: @society, organizer: @organizer, title: "Future Night",
                           description: "x", location: "den", start_time: 3.days.from_now,
                           end_time: 3.days.from_now + 2.hours, presentation: @deck)
    other = users(:seth)
    SocietyMembership.create!(user: other, society: @society, role: "member", status: "active")
    EventRsvp.create!(user: other, event: future, status: "yes")
    sign_in other
    assert_no_difference "PresentationReview.count" do
      post presentation_deck_reviews_path(@deck), params: { presentation_review: { rating: 5.0 } }
    end
  end

  test "one review per person, editable and removable" do
    sign_in @attendee
    post presentation_deck_reviews_path(@deck), params: { presentation_review: { rating: 4.0 } }
    assert_no_difference "PresentationReview.count" do
      post presentation_deck_reviews_path(@deck), params: { presentation_review: { rating: 2.0 } }
    end
    review = @attendee.presentation_reviews.last
    patch presentation_deck_review_path(@deck, review), params: { presentation_review: { rating: 5.0, body: "Even better on reflection" } }
    assert_equal 5.0, review.reload.rating.to_f
    delete presentation_deck_review_path(@deck, review)
    assert_not PresentationReview.exists?(review.id)
  end

  test "reviews render on the deck page with the average" do
    PresentationReview.new(presentation: @deck, user: @attendee, rating: 4.0, body: "A fine thread").save!(validate: false)
    get presentation_path(@deck)
    assert_response :success
    assert_match "A fine thread", response.body
    assert_match "1 review", response.body
  end
end

# Part A: events optionally carry a deck and a host (member or guest name).
class EventDeckHostTest < ActionDispatch::IntegrationTest
  setup do
    @organizer = users(:john)
    @member = users(:jane)
    @society = Society.create!(name: "Deck Host Club", description: "x", creator: @organizer, is_private: false)
    SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
    @deck = Presentation.create!(author: @organizer, title: "Offerable Deck", content: "A story.", price: 9.99)
    @deck.update_column(:published, true)
  end

  def create_event(extra = {})
    sign_in @organizer
    post society_events_path(@society), params: { event: {
      society_id: @society.id, title: "Composed Night", description: "x", location: "den",
      start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours
    }.merge(extra) }
    Event.find_by(title: "Composed Night")
  end

  test "an event can carry a deck from the creation form" do
    event = create_event(presentation_id: @deck.id)
    assert_equal @deck, event.presentation
  end

  test "an event without a deck is first-class" do
    event = create_event
    assert_nil event.presentation
    assert_predicate event, :persisted?
  end

  test "a deck the creator cannot offer is dropped silently" do
    other_deck = Presentation.create!(author: users(:one), title: "Someone Elses Deck", content: "A story.", price: 9.99)
    other_deck.update_column(:published, true)
    event = create_event(presentation_id: other_deck.id)
    assert_nil event.presentation
  end

  test "a member name in the host field becomes the real host" do
    event = create_event(host_query: @member.full_name)
    assert_equal @member, event.host
    assert_nil event.host_name
  end

  test "an unknown name becomes the guest presenter" do
    event = create_event(host_query: "Pappy Van Winkle")
    assert_nil event.host
    assert_equal "Pappy Van Winkle", event.host_name
  end

  test "managers set and clear the deck from the event page" do
    event = create_event
    patch assign_deck_society_event_path(@society, event), params: { presentation_id: @deck.id }
    assert_equal @deck, event.reload.presentation
    patch assign_deck_society_event_path(@society, event), params: { presentation_id: "" }
    assert_nil event.reload.presentation
  end

  test "a plain member cannot set the deck" do
    event = create_event
    sign_in @member
    patch assign_deck_society_event_path(@society, event), params: { presentation_id: @deck.id }
    assert_nil event.reload.presentation
  end

  test "the host can set the deck" do
    event = create_event
    event.update!(host: @member)
    sign_in @member
    patch assign_deck_society_event_path(@society, event), params: { presentation_id: @deck.id }
    assert_equal @deck, event.reload.presentation
  end
end

# The cached summary on the deck (reviews_count / reviews_average) is what
# the library and homepage cards read, so it must track reality through
# every path. Recomputed, never incremented.
class DeckReviewStatsTest < ActiveSupport::TestCase
  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Stats Deck", content: "x", price: 5)
    @deck.update_column(:published, true)
    @a = users(:john)
    @b = users(:jane)
    [ @a, @b ].each { |u| UserPresentation.create!(user: u, presentation: @deck, purchase_type: "direct", purchased_at: Time.current) }
  end

  test "a deck with no reviews reports nothing to show" do
    assert_equal 0, @deck.reviews_count
    assert_nil @deck.average_review_rating
    assert_not @deck.reviewed?
  end

  test "the cache follows creates, edits, and deletes" do
    r1 = PresentationReview.create!(presentation: @deck, user: @a, rating: 4.0)
    assert_equal [ 1, 4.0 ], [ @deck.reload.reviews_count, @deck.average_review_rating ]

    PresentationReview.create!(presentation: @deck, user: @b, rating: 5.0)
    assert_equal [ 2, 4.5 ], [ @deck.reload.reviews_count, @deck.average_review_rating ]

    r1.update!(rating: 2.0) # an edit must move the average
    assert_equal 3.5, @deck.reload.average_review_rating

    r1.destroy
    assert_equal [ 1, 5.0 ], [ @deck.reload.reviews_count, @deck.average_review_rating ]
  end

  test "refreshing is idempotent and self-healing" do
    PresentationReview.create!(presentation: @deck, user: @a, rating: 3.0)
    @deck.update_columns(reviews_count: 99, reviews_average: 1.0) # simulate drift
    @deck.refresh_review_stats!
    assert_equal [ 1, 3.0 ], [ @deck.reload.reviews_count, @deck.average_review_rating ]
  end
end
