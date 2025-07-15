class AddSubscriptionPausedAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :subscription_paused_at, :datetime
  end
end
