class AddIsPrivateToSocieties < ActiveRecord::Migration[8.0]
  def change
    add_column :societies, :is_private, :boolean
  end
end
