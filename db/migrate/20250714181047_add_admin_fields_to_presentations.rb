class AddAdminFieldsToPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :presentations, :whiskey_recommendations, :text
    add_column :presentations, :tasting_notes, :text
  end
end
