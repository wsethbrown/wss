# B6 / M8: a webhook claim used to mean "processed". A deploy or kill between
# the claim and the end of the handler then lost the event for good. Now a claim
# is in flight until processed_at is set, and a claim left unfinished for ten
# minutes can be re-claimed by Stripe's redelivery.
#
# Every existing row was either processed or released (deleted) before this
# column existed, so all are backfilled as processed.
class AddProcessedAtToStripeEvents < ActiveRecord::Migration[8.0]
  def up
    add_column :stripe_events, :processed_at, :datetime
    execute "UPDATE stripe_events SET processed_at = created_at WHERE processed_at IS NULL"
  end

  def down
    remove_column :stripe_events, :processed_at
  end
end
