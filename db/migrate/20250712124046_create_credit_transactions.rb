class CreateCreditTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_transactions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :transaction_type, null: false
      t.integer :amount, null: false
      t.references :presentation, foreign_key: true
      t.text :description

      t.timestamps
    end
    
    add_index :credit_transactions, :transaction_type
    add_index :credit_transactions, [:user_id, :created_at]
  end
end
