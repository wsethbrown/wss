class AddStripeFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :stripe_customer_id, :string
    add_column :users, :stripe_subscription_id, :string
    add_column :users, :subscription_status, :string
    add_column :users, :subscription_plan, :string
    add_column :users, :subscription_ends_at, :datetime
  end
end
