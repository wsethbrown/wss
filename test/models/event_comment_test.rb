require "test_helper"

class EventCommentTest < ActiveSupport::TestCase
  test "valid on an upcoming event with a body" do
    comment = EventComment.new(event: events(:mystery_flight), user: users(:john), body: "Bringing the Weller.")
    assert comment.valid?
  end

  test "invalid without a body" do
    comment = EventComment.new(event: events(:mystery_flight), user: users(:john), body: "  ")
    assert_not comment.valid?
  end

  test "invalid past 2000 characters" do
    comment = EventComment.new(event: events(:mystery_flight), user: users(:john), body: "a" * 2001)
    assert_not comment.valid?
  end

  test "cannot be created more than a week after the event ends" do
    comment = EventComment.new(event: events(:spring_blind), user: users(:john), body: "Too late.")
    assert_not comment.valid?
  end

  test "can be created within the week after the event ends" do
    event = Event.create!(society: societies(:single_malt), organizer: users(:admin),
                          title: "Last week's night", description: "x", location: "x",
                          start_time: 6.days.ago - 2.hours, end_time: 6.days.ago)
    comment = EventComment.new(event: event, user: users(:john), body: "Great night.")
    assert comment.valid?
  end

  test "existing comments survive past the window; only creation is gated" do
    event = Event.create!(society: societies(:single_malt), organizer: users(:admin),
                          title: "Recent night", description: "x", location: "x",
                          start_time: 6.days.ago - 2.hours, end_time: 6.days.ago)
    comment = EventComment.create!(event: event, user: users(:john), body: "In the window.")
    event.update_columns(start_time: 3.weeks.ago, end_time: 3.weeks.ago + 2.hours)
    assert comment.reload.valid?
    assert comment.update(body: "Edited later")
  end

  test "comments_open? tracks end_time plus seven days" do
    assert events(:mystery_flight).comments_open?
    assert_not events(:spring_blind).comments_open?
  end
end
