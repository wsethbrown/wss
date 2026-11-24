class AddMagicLinkReturnToToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :magic_link_return_to, :string
  end
end
