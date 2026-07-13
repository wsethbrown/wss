class AddAdminRoleToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :admin_role, :string, null: false, default: "none"
    add_index :users, :admin_role
    # Existing admins become full admins (delete rights preserved).
    execute "UPDATE users SET admin_role = 'full' WHERE is_admin = true"
  end

  def down
    remove_column :users, :admin_role
  end
end
