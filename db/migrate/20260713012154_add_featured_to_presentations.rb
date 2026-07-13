class AddFeaturedToPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :presentations, :featured, :boolean, null: false, default: false
    add_index :presentations, :featured
  end
end
