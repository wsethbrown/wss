# B6 / M18: every Stripe webhook looks the member up by stripe_customer_id,
# which had no index (a full scan per event) and no uniqueness (two users on
# one customer would make the lookup pick one arbitrarily).
#
# Built concurrently so the users table stays writable. If two users already
# share a customer id the migration stops with their ids rather than guessing
# which one owns the customer: resolve them by hand (check the customer in the
# Stripe dashboard), then re-run.
class AddUniqueIndexToUsersStripeCustomerId < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_users_on_stripe_customer_id_unique".freeze

  def up
    duplicates = select_rows(<<~SQL)
      SELECT stripe_customer_id, string_agg(id::text, ', ' ORDER BY id)
      FROM users
      WHERE stripe_customer_id IS NOT NULL
      GROUP BY stripe_customer_id
      HAVING count(*) > 1
    SQL
    if duplicates.any?
      details = duplicates.map { |customer, ids| "customer #{customer.inspect} -> users #{ids}" }.join("; ")
      raise ActiveRecord::MigrationError,
            "Cannot add a unique index on users.stripe_customer_id: #{duplicates.size} customer id(s) " \
            "are shared by more than one user (#{details}). Resolve them by hand, then re-run."
    end

    add_index :users, :stripe_customer_id, unique: true, where: "stripe_customer_id IS NOT NULL",
              name: INDEX_NAME, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :users, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
