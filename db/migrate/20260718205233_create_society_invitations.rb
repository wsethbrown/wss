class CreateSocietyInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :society_invitations do |t|
      t.references :society, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.datetime :responded_at
      t.timestamps
    end
    # One live invitation per person per society at a time.
    add_index :society_invitations, [ :society_id, :user_id ], unique: true,
              where: "status = 'pending'", name: "index_society_invitations_on_pending_pair"
  end
end
