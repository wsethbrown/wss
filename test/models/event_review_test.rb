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
    assert_includes dup.errors[:bottle_id], "already has your review, edit it instead"
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

# The RSVP window (owner decision, November 2026): answers can be changed or
# withdrawn until the event starts. A NEW yes, from someone not currently at
# yes, closes 24 hours before the start, except for events created less than
# 24 hours before they start, which stay open until the start. Maybe and
# can't-make-it are always allowed until the start.
class RsvpCutoffTest < ActiveSupport::TestCase
  setup do
    @society = societies(:single_malt)
  end

  # An event created `created` ago that starts `duration` from now.
  def event_starting_in(duration, created: 3.days.ago)
    start = duration.from_now
    travel_to(created) do
      Event.create!(society: @society, organizer: users(:admin), title: "Night", location: "The bar",
                    description: "x", start_time: start, end_time: start + 2.hours)
    end
  end

  test "a new yes closes 24 hours before an event announced well ahead" do
    soon = event_starting_in(12.hours)
    rsvp = EventRsvp.new(event: soon, user: users(:john), status: "yes")
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:base], "New yes answers close 24 hours before the event"
    assert soon.new_yes_closed?
    assert_not soon.rsvp_closed?, "maybe and no stay open until the start"
  end

  test "maybe and can't make it stay open until the start" do
    soon = event_starting_in(12.hours)
    assert EventRsvp.new(event: soon, user: users(:john), status: "maybe").valid?
    assert EventRsvp.new(event: soon, user: users(:jane), status: "no").valid?
    assert soon.can_rsvp?(users(:john))
  end

  test "a yes can be changed or withdrawn inside the last day, but not restored from maybe" do
    event = event_starting_in(3.days)
    rsvp = EventRsvp.create!(event: event, user: users(:john), status: "yes")
    travel_to(event.start_time - 2.hours) do
      assert rsvp.can_change_response?
      rsvp.status = "maybe"
      assert rsvp.save, rsvp.errors.full_messages.to_sentence
      rsvp.status = "yes"
      assert_not rsvp.valid?, "back to yes is a new yes"
      rsvp.status = "no"
      assert rsvp.save
    end
  end

  test "an existing yes stays valid inside the last day" do
    event = event_starting_in(3.days)
    rsvp = EventRsvp.create!(event: event, user: users(:john), status: "yes")
    travel_to(event.start_time - 2.hours) do
      rsvp.note = "Bringing ice"
      assert rsvp.save, rsvp.errors.full_messages.to_sentence
    end
  end

  test "an event created inside 24 hours takes yes answers until it starts" do
    tonight = Event.create!(society: @society, organizer: users(:admin), title: "Drinks tonight", location: "The bar",
                            description: "x", start_time: 6.hours.from_now, end_time: 8.hours.from_now)
    assert_not tonight.new_yes_closed?
    rsvp = EventRsvp.new(event: tonight, user: users(:john), status: "yes")
    assert rsvp.valid?, rsvp.errors.full_messages.to_sentence
    assert tonight.can_rsvp?(users(:john))
  end

  test "nothing can be answered once the event has started" do
    event = event_starting_in(3.days)
    rsvp = EventRsvp.create!(event: event, user: users(:john), status: "yes")
    travel_to(event.start_time + 1.minute) do
      assert event.rsvp_closed?
      assert_not rsvp.can_change_response?
      rsvp.status = "no"
      assert_not rsvp.valid?
      assert_not event.can_rsvp?(users(:jane))
    end
  end

  test "RSVPs stay open with more than a day's notice" do
    rsvp = EventRsvp.new(event: events(:mystery_flight), user: users(:jane), status: "yes")
    assert rsvp.valid?, rsvp.errors.full_messages.to_sentence
  end
end
