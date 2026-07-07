class AddFlavorWheelToReviews < ActiveRecord::Migration[8.0]
  def change
    # User-set flavor intensities (family => 0.0..1.0). When present it
    # overrides the text-derived profile for wheels and waves.
    add_column :reviews, :flavor_wheel, :jsonb, null: false, default: {}
  end
end
