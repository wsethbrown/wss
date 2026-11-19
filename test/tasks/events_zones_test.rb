require "test_helper"
require "rake"

# B15b: `rake events:zones` is a read-only report.
class EventsZonesTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("events:zones")
    Rake::Task["events:zones"].reenable
  end

  test "prints upcoming events with society, location and zone, and changes nothing" do
    society = societies(:whiskey_lovers)
    society.update_columns(location: "Portland, OR") if society.respond_to?(:location)
    event = Event.create!(society: society, organizer: users(:john), title: "Zone Report Night", description: "x",
                          location: "Den", start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours,
                          time_zone: "America/Chicago")
    snapshot = Event.order(:id).pluck(:id, :time_zone, :updated_at)

    out, = capture_io { Rake::Task["events:zones"].invoke }

    assert_includes out, "Zone Report Night"
    assert_includes out, "America/Chicago"
    assert_includes out, society.name
    assert_includes out, event.id.to_s
    assert_equal snapshot, Event.order(:id).pluck(:id, :time_zone, :updated_at)
  end
end
