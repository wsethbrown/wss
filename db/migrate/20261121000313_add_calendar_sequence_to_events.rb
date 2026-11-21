# SEQUENCE for an event's .ics (RFC 5545): rises each time the time or the
# location changes, so a calendar replaces its copy of the event.
class AddCalendarSequenceToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :calendar_sequence, :integer, default: 0, null: false
  end
end
