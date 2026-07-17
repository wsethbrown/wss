class DropWhiskeyShelfFromUsers < ActiveRecord::Migration[8.0]
  # The shelf now lives in shelf_items (chips, bottle-linked). CreateShelfItems
  # backfilled this column's lines; the owner has confirmed the legacy text
  # doesn't need to be preserved beyond that (2026-07-17).
  def change
    remove_column :users, :whiskey_shelf, :text
  end
end
