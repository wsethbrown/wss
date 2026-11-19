# B5 / M1: one monthly credit per member per calendar month, enforced by the
# database. Monthly grants carry grant_key "monthly:<user_id>:<YYYY-MM>"; every
# grant path (daily job, renewal webhook, admin button, welcome credit) uses the
# same key, so a unique index makes a double grant impossible. Existing rows keep
# a NULL key (Postgres unique indexes ignore NULLs), so nothing is backfilled.
class AddGrantKeyToCreditTransactions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :credit_transactions, :grant_key, :string
    add_index :credit_transactions, :grant_key, unique: true, algorithm: :concurrently
  end
end
