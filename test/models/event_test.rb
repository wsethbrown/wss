require "test_helper"

# B15 (I3): an event carries the organiser's time zone so emails (rendered in
# the jobs process, where Time.zone is UTC) show the time people expect.
class EventTest < ActiveSupport::TestCase
  def build(attrs = {})
    start = Time.utc(2027, 1, 15, 0, 30) # 7:30 PM EST on Jan 14
    Event.new({ society: societies(:whiskey_lovers), organizer: users(:john), title: "Zone Night",
                description: "x", location: "x", start_time: start, end_time: start + 2.hours }.merge(attrs))
  end

  test "renders times in the event's own zone with an abbreviation" do
    event = build(time_zone: "America/New_York")
    assert_equal "Thursday, January 14 at 7:30 PM EST", event.start_time_label
  end

  test "uses daylight abbreviations in summer" do
    event = build(time_zone: "America/New_York", start_time: Time.utc(2027, 7, 15, 23, 30))
    assert_equal "Thursday, July 15 at 7:30 PM EDT", event.start_time_label
  end

  test "falls back to America/New_York when no zone is stored" do
    event = build(time_zone: nil)
    assert_equal "America/New_York", event.effective_time_zone.tzinfo.name
    assert_match(/7:30 PM EST\z/, event.start_time_label)
  end

  test "an unknown zone name is invalid" do
    event = build(time_zone: "Mars/Olympus")
    assert_not event.valid?
    assert event.errors[:time_zone].any?
  end

  test "does not depend on the ambient Time.zone" do
    event = build(time_zone: "America/Chicago")
    Time.use_zone("Tokyo") { assert_match(/6:30 PM CST\z/, event.start_time_label) }
  end
end
