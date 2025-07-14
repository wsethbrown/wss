class AddFieldsToPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :presentations, :duration, :string
    add_column :presentations, :difficulty, :string
    add_column :presentations, :image, :string
    add_column :presentations, :published, :boolean, default: false
    add_column :presentations, :rating, :decimal, precision: 3, scale: 2
    add_column :presentations, :review_count, :integer, default: 0
  end
end
