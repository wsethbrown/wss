class AddPasswordSetManuallyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_set_manually, :boolean, default: false, null: false
  end
end
