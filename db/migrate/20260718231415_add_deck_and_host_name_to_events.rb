class AddDeckAndHostNameToEvents < ActiveRecord::Migration[8.0]
  def change
    # The deck presented that night; OPTIONAL by owner rule — an event
    # without a WSS deck is a first-class event.
    add_reference :events, :presentation, foreign_key: true
    # Guest presenter fallback when the host is not a member (host_id wins).
    add_column :events, :host_name, :string
  end
end
