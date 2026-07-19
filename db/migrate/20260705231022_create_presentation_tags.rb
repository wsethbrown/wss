class CreatePresentationTags < ActiveRecord::Migration[8.0]
  def change
    create_table :presentation_tags do |t|
      t.references :presentation, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.timestamps
    end
    add_index :presentation_tags, [ :presentation_id, :tag_id ], unique: true
  end
end
