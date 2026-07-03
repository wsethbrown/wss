class AddMagicLinkFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    # Dedicated magic-link columns so magic links no longer collide with Devise's
    # password-reset token (reset_password_token / reset_password_sent_at).
    add_column :users, :magic_link_token, :string
    add_column :users, :magic_link_sent_at, :datetime
    add_index :users, :magic_link_token, unique: true
  end
end
