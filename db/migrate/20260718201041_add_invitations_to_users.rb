class AddInvitationsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :invitation_token_digest, :string
    add_index :users, :invitation_token_digest
    add_column :users, :invitation_sent_at, :datetime
    add_column :users, :invitation_accepted_at, :datetime
    add_reference :users, :invited_by, foreign_key: { to_table: :users }
  end
end
