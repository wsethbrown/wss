class AddDetailedFieldsToPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :presentations, :what_youll_learn, :text
    add_column :presentations, :slides_preview, :text
  end
end
