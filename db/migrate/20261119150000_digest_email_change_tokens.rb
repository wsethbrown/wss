# B8 (S6): users.email_change_token now holds an HMAC digest of the token
# (Auth::EmailChangeService, same digest as magic links), never the raw value.
#
# Pending changes made before this deploy stored the raw token in clear. They
# are invalidated, not migrated: the token, the pending address and the expiry
# are cleared, so those people simply request the change again (links lived
# at most an hour). Adds a unique index for the digest lookup, built
# concurrently so the users table is never locked.
class DigestEmailChangeTokens < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    cleared = execute(<<~SQL).cmd_tuples
      UPDATE users
         SET email_change_token = NULL,
             unconfirmed_email = NULL,
             email_change_token_expires_at = NULL
       WHERE email_change_token IS NOT NULL
    SQL
    say "Cleared #{cleared} pending plain-text email-change token(s)"

    add_index :users, :email_change_token, unique: true, algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    # The cleared plain-text tokens are not restorable (and must not be).
    remove_index :users, :email_change_token, algorithm: :concurrently, if_exists: true
  end
end
