# B15 (I3): the organiser's zone, so emails (rendered in the jobs process,
# where Time.zone is UTC) show the time the organiser meant. Existing events
# are backfilled with the fallback zone; see Event::FALLBACK_TIME_ZONE.
class AddTimeZoneToEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :time_zone, :string
    execute "UPDATE events SET time_zone = 'America/New_York'"
  end

  def down
    remove_column :events, :time_zone
  end
end
