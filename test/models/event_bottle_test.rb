require "test_helper"

class EventBottleTest < ActiveSupport::TestCase
  test "valid pour saves" do
    pour = EventBottle.new(event: events(:mystery_flight), bottle: bottles(:eagle_rare),
                           position: 2, label: "The closer")
    assert pour.valid?, pour.errors.full_messages.to_sentence
  end

  test "a bottle can appear only once per event" do
    dup = EventBottle.new(event: events(:spring_blind), bottle: bottles(:ardbeg_10), position: 9)
    assert_not dup.valid?
    assert_includes dup.errors[:bottle_id], "is already on this event's pour list"
  end

  test "ordered scope sorts by position" do
    assert_equal [bottles(:ardbeg_10), bottles(:glendronach_12), bottles(:four_roses_sb)],
                 events(:spring_blind).event_bottles.ordered.map(&:bottle)
  end

  test "pours are revealed whenever the secret toggle is off" do
    assert events(:spring_blind).pours_revealed? # past event
    upcoming = Event.new(start_time: 1.week.from_now, end_time: 1.week.from_now + 2.hours)
    assert upcoming.pours_revealed?              # upcoming but never secret
  end

  test "secret pours hide until end_time, then auto-reveal" do
    event = events(:mystery_flight)
    assert_not event.pours_revealed?
    event.end_time = 1.minute.ago
    assert event.pours_revealed?
  end

  test "secret pours are visible early only to the people who run the night" do
    event = events(:mystery_flight) # organizer: admin (also the society's admin)
    assert event.pours_visible_to?(users(:admin))    # organizer / society admin / global admin
    assert_not event.pours_visible_to?(users(:seth)) # RSVP'd member — still no peeking
    assert_not event.pours_visible_to?(users(:jane)) # outsider
    assert_not event.pours_visible_to?(nil)          # signed out
  end

  test "group_average counts only the night's event reviews" do
    pour = event_bottles(:spring_blind_pour_one)
    assert_in_delta 4.25, pour.group_average, 0.001 # john 4.5, seth 4.0
    Review.create!(user: users(:jane), bottle: bottles(:ardbeg_10), rating: 1.0) # solo — must not count
    assert_in_delta 4.25, pour.group_average, 0.001
  end

  test "a pour with reviews cannot be removed" do
    pour = event_bottles(:spring_blind_pour_one)
    assert_not pour.destroy
    assert_includes pour.errors[:base], "Can't remove a pour that has reviews"
    assert EventBottle.exists?(pour.id)
  end

  test "an event with reviews cannot be destroyed, an unreviewed one can" do
    assert_not events(:spring_blind).destroy
    assert Event.exists?(events(:spring_blind).id)
    assert events(:mystery_flight).destroy
  end
end
