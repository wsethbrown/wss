class CreateSocietyMemberships < ActiveRecord::Migration[8.0]
  def change
    create_table :society_memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :society, null: false, foreign_key: true
      t.string :role, null: false, default: 'member'
      t.string :status, null: false, default: 'active'

      t.timestamps
    end

    add_index :society_memberships, [:user_id, :society_id], unique: true
    add_index :society_memberships, :role
    add_index :society_memberships, :status
  end
end
