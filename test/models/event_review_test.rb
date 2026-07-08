require "test_helper"

class EventReviewTest < ActiveSupport::TestCase
  test "RSVP'd member reviews a revealed pour" do
    # seth RSVP'd yes and hasn't reviewed the third pour yet
    review = Review.new(user: users(:seth), bottle: bottles(:four_roses_sb),
                        event: events(:spring_blind), rating: 4.5, notes: "Late entry.")
    assert review.valid?, review.errors.full_messages.to_sentence
  end

  test "rejects a bottle that isn't on the pour list" do
    review = Review.new(user: users(:seth), bottle: bottles(:eagle_rare),
                        event: events(:spring_blind), rating: 4.0)
    assert_not review.valid?
    assert_includes review.errors[:base], "That bottle isn't on this event's pour list"
  end

  test "rejects reviewers without a yes RSVP" do
    review = Review.new(user: users(:jane), bottle: bottles(:ardbeg_10),
                        event: events(:spring_blind), rating: 4.0)
    assert_not review.valid?
    assert_includes review.errors[:base], %(Only members who RSVP'd "going" can review this event's pours)
  end

  test "rejects reviews while the pours are still secret" do
    review = Review.new(user: users(:seth), bottle: bottles(:lagavulin),
                        event: events(:mystery_flight), rating: 4.0)
    assert_not review.valid?
    assert_includes review.errors[:base], "The pours haven't been revealed yet"
  end

  test "solo and event reviews of the same bottle coexist; duplicates per context don't" do
    solo = Review.new(user: users(:john), bottle: bottles(:ardbeg_10), rating: 4.0)
    assert solo.valid?, solo.errors.full_messages.to_sentence # event review exists; solo slot is free

    dup = Review.new(user: users(:john), bottle: bottles(:ardbeg_10),
                     event: events(:spring_blind), rating: 4.0)
    assert_not dup.valid?
    assert_includes dup.errors[:bottle_id], "already has your review — edit it instead"
  end

  test "organizer cannot review a secret pour before reveal" do
    # Admin organizes mystery_flight (secret pours, future end_time).
    # Even with a yes RSVP, the reveal gate blocks the review.
    EventRsvp.create!(event: events(:mystery_flight), user: users(:admin), status: "yes")

    review = Review.new(user: users(:admin), bottle: bottles(:lagavulin),
                        event: events(:mystery_flight), rating: 4.0)
    assert_not review.valid?
    assert_includes review.errors[:base], "The pours haven't been revealed yet"
  end
end

class RsvpCutoffTest < ActiveSupport::TestCase
  test "RSVPs close 24 hours before the event" do
    society = societies(:single_malt)
    soon = Event.create!(society: society, organizer: users(:admin), title: "Tomorrow Night",
                         location: "The bar", description: "Short notice",
                         start_time: 12.hours.from_now, end_time: 14.hours.from_now)
    rsvp = EventRsvp.new(event: soon, user: users(:john), status: "yes")
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:base], "RSVPs close 24 hours before the event"
    assert soon.rsvp_closed?
    assert_not soon.can_rsvp?(users(:john))
  end

  test "RSVPs stay open with more than a day's notice" do
    rsvp = EventRsvp.new(event: events(:mystery_flight), user: users(:jane), status: "maybe")
    assert rsvp.valid?, rsvp.errors.full_messages.to_sentence
  end
end
