class AddPreviewSlideCountToPresentations < ActiveRecord::Migration[8.0]
  def change
    # How many rendered slides a non-buyer sees before the paywall fade.
    # The first slide is typically a title, so 3 is a sensible default.
    add_column :presentations, :preview_slide_count, :integer, default: 3, null: false
  end
end
