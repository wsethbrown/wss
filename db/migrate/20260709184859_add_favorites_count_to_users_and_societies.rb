class AddFavoritesCountToUsersAndSocieties < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :favorites_count, :integer, default: 0, null: false
    add_column :societies, :favorites_count, :integer, default: 0, null: false

    # Backfill: follower counts for existing users/societies.
    execute <<~SQL
      UPDATE users SET favorites_count = (
        SELECT COUNT(*) FROM favorites
        WHERE favorites.favoritable_type = 'User' AND favorites.favoritable_id = users.id
      )
    SQL
    execute <<~SQL
      UPDATE societies SET favorites_count = (
        SELECT COUNT(*) FROM favorites
        WHERE favorites.favoritable_type = 'Society' AND favorites.favoritable_id = societies.id
      )
    SQL
  end

  def down
    remove_column :users, :favorites_count
    remove_column :societies, :favorites_count
  end
end
