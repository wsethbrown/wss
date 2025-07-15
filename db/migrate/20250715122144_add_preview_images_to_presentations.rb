class AddPreviewImagesToPresentations < ActiveRecord::Migration[8.0]
  def change
    # ActiveStorage will handle the preview images through has_many_attached
    # No need to add columns to the presentations table
  end
end
