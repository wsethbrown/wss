class AddWhiskeyShelfToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :whiskey_shelf, :text
  end
end
