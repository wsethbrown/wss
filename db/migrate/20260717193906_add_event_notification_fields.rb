class AddEventNotificationFields < ActiveRecord::Migration[8.0]
  def change
    # A guest's optional note to the host, carried on the RSVP and included in
    # the host's notification email.
    add_column :event_rsvps, :note, :string

    # Per-user mute for society/event notification emails (default on).
    add_column :users, :event_emails, :boolean, null: false, default: true
  end
end
