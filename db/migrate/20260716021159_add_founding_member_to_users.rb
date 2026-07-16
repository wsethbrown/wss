class AddFoundingMemberToUsers < ActiveRecord::Migration[8.0]
  def change
    # Founding Member status: earned by taking a founding plan while slots
    # remain, kept while the subscription never CANCELS (pausing is fine).
    # founding_revoked_at is permanent: once revoked, never offered again.
    add_column :users, :founding_member, :boolean, null: false, default: false
    add_column :users, :founding_revoked_at, :datetime
    add_index :users, :founding_member
  end
end
