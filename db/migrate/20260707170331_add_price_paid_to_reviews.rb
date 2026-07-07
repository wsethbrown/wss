class AddPricePaidToReviews < ActiveRecord::Migration[8.0]
  def change
    add_column :reviews, :price_paid, :decimal, precision: 8, scale: 2
  end
end
