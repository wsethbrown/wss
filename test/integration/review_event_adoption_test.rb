require "test_helper"

# Owner rule: reviewing a bottle within a week of attending an event where it
# was poured links the review to that event; otherwise it's a plain solo review.
class ReviewEventAdoptionTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:jane)
    @bottle = bottles(:lagavulin) # fixture rule: lagavulin has zero reviews
    @society = societies(:whiskey_lovers)
  end

  # A past event that poured the bottle, with (optionally) an attending RSVP.
  # Built in the future to satisfy validations, then moved into the past.
  def attended_event(ended_ago:, rsvp: true)
    event = Event.create!(society: @society, organizer: users(:john), title: "Tasting night",
                          description: "x", location: "The den",
                          start_time: 2.days.from_now, end_time: 2.days.from_now + 3.hours)
    EventBottle.create!(event: event, bottle: @bottle, position: 1)
    if rsvp
      r = EventRsvp.new(user: @user, event: event, status: "yes")
      r.save!(validate: false)
    end
    event.update_columns(start_time: ended_ago - 3.hours, end_time: ended_ago)
    event
  end

  def post_review
    post bottle_reviews_path(@bottle), params: { review: { rating: 4.0, notes: "peaty" } }
  end

  test "a review within a week of an attended pour links to the event" do
    event = attended_event(ended_ago: 2.days.ago)
    sign_in @user

    post_review
    review = Review.order(:created_at).last
    assert_equal event.id, review.event_id
    follow_redirect!
    assert_match(/linked to Tasting night/, @response.body)
  end

  test "an event older than a week does not adopt the review" do
    attended_event(ended_ago: 8.days.ago)
    sign_in @user

    post_review
    assert_nil Review.order(:created_at).last.event_id
  end

  test "no adoption without an attending RSVP" do
    attended_event(ended_ago: 2.days.ago, rsvp: false)
    sign_in @user

    post_review
    assert_nil Review.order(:created_at).last.event_id
  end

  test "no adoption when the bottle was not poured at the event" do
    event = attended_event(ended_ago: 2.days.ago)
    event.event_bottles.delete_all
    sign_in @user

    post_review
    assert_nil Review.order(:created_at).last.event_id
  end

  test "a second review falls back to solo when the event slot is taken" do
    event = attended_event(ended_ago: 2.days.ago)
    Review.new(user: @user, bottle: @bottle, event: event, rating: 3.0).save!(validate: false)
    sign_in @user

    post_review
    review = Review.order(:created_at).last
    assert_nil review.event_id
  end

  test "the most recent qualifying event wins" do
    older = attended_event(ended_ago: 5.days.ago)
    newer = attended_event(ended_ago: 1.day.ago)
    sign_in @user

    post_review
    assert_equal newer.id, Review.order(:created_at).last.event_id
  end
end
