class CreateSocietyApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :society_applications do |t|
      t.references :user, null: false, foreign_key: true
      t.references :society, null: false, foreign_key: true
      t.text :message
      t.string :status

      t.timestamps
    end
  end
end
