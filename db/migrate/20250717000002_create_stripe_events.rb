class CreateStripeEvents < ActiveRecord::Migration[8.0]
  def change
    # Ledger of processed Stripe webhook events so retried/duplicate deliveries are
    # handled exactly once (prevents duplicate credit grants, etc.).
    create_table :stripe_events do |t|
      t.string :stripe_event_id, null: false
      t.string :event_type
      t.timestamps
    end
    add_index :stripe_events, :stripe_event_id, unique: true
  end
end
