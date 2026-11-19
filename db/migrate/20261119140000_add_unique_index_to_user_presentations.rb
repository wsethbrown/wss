# B7 / M2: user_presentations had no uniqueness, so a double-click on "unlock
# with a credit" spent two credits and the webhook and return path could both
# write a row. The merge keeps one row per (user, deck): a direct purchase over
# a credit unlock, otherwise the oldest. The unique index is then built
# concurrently so the table stays writable.
#
# The merge is irreversible (the deleted duplicates are not restored); `down`
# only drops the index and never raises.
class AddUniqueIndexToUserPresentations < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_user_presentations_on_user_id_and_presentation_id".freeze

  def up
    merge_duplicates
    add_index :user_presentations, [ :user_id, :presentation_id ],
              unique: true, name: INDEX_NAME, algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :user_presentations, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end

  def merge_duplicates
    removed = execute(<<~SQL.squish).cmd_tuples
      DELETE FROM user_presentations
      WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (
            PARTITION BY user_id, presentation_id
            ORDER BY (purchase_type = 'direct') DESC, created_at ASC, id ASC
          ) AS rn
          FROM user_presentations
        ) ranked
        WHERE rn > 1
      )
    SQL
    say "merged #{removed} duplicate user_presentations row(s)"
  end
end
