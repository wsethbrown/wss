class AddAboutToSocieties < ActiveRecord::Migration[8.0]
  def change
    add_column :societies, :about, :text
  end
end
