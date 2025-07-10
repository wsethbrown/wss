class AddBannerPositionToSocieties < ActiveRecord::Migration[8.0]
  def change
    add_column :societies, :banner_position, :string, default: 'center center'
  end
end
