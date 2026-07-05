class AddInviteTokenToSocieties < ActiveRecord::Migration[8.0]
  def change
    add_column :societies, :invite_token, :string
    add_index :societies, :invite_token, unique: true
  end
end
