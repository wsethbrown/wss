class AddTastingFieldsToPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :presentations, :nose_notes, :text
    add_column :presentations, :palate_notes, :text
    add_column :presentations, :finish_notes, :text
    add_column :presentations, :body_notes, :text
  end
end
