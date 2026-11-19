# B6 / M19: the webhook wrote "cancelled" while the admin screens counted and
# filtered "canceled" (Stripe's spelling), so cancelled members were split
# across two values. Stripe's spelling wins; User now declares the status as an
# enum of Stripe's values.
#
# The down direction is a no-op: once merged, rows that were "cancelled" cannot
# be told apart from rows that were always "canceled", and both mean the same.
class NormalizeCancelledSubscriptionStatus < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE users SET subscription_status = 'canceled' WHERE subscription_status = 'cancelled'"
  end

  def down
    # Intentionally nothing; see above.
  end
end
