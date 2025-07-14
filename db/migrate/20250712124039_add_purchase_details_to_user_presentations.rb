class AddPurchaseDetailsToUserPresentations < ActiveRecord::Migration[8.0]
  def change
    add_column :user_presentations, :purchase_price, :decimal, precision: 10, scale: 2
    add_column :user_presentations, :stripe_payment_intent_id, :string
    
    # Update existing purchase_type column to have constraints
    change_column_null :user_presentations, :purchase_type, false, 'credit'
    change_column_default :user_presentations, :purchase_type, 'credit'
    
    add_index :user_presentations, :purchase_type
  end
end
