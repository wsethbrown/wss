require "test_helper"
require Rails.root.join("db/migrate/20261119160000_add_time_zone_to_events")

# B15: the backfill is plain SQL. It must not run model callbacks, so it can
# never enqueue event emails, notifications or reminders.
class AddTimeZoneToEventsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "backfill gives every existing event the fallback zone and enqueues nothing" do
    society = societies(:whiskey_lovers)
    start = 5.days.from_now
    ids = 2.times.map do |i|
      Event.create!(society: society, organizer: users(:john), title: "Old Night #{i}", description: "x",
                    location: "x", start_time: start, end_time: start + 2.hours).id
    end
    clear_enqueued_jobs
    migration = AddTimeZoneToEvents.new
    migration.verbose = false if migration.respond_to?(:verbose=)

    assert_no_enqueued_jobs do
      # (mail goes through deliver_later, so this covers emails too)
      migration.migrate(:down)
      Event.reset_column_information
      migration.migrate(:up)
      Event.reset_column_information
    end
    assert_equal [ "America/New_York" ], Event.where(id: ids).pluck(:time_zone).uniq
    assert_equal 0, Event.where(time_zone: nil).count
  end
end
