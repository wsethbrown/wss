# Finds, and on request deletes, accounts nobody ever used: the junk sign-ups a
# script created through the public magic-link form (August-October 2026),
# when opening the emailed link (a corporate mail scanner did) created the
# account. Driven by `rake users:purge_unused`; dry run unless confirmed.
#
# A user is a candidate only when EVERY one of these holds:
# - no identity: blank first and last name, blank bio, no profile image,
#   password never set by hand, no OAuth provider/uid, no pending email change;
# - never invited (no inviter, no sent or accepted invitation);
# - admin_role none, not is_admin;
# - no subscription trace: no Stripe customer or subscription id, blank
#   subscription status and plan, no paused/ends dates, not founding;
# - zero credits;
# - no preference changed (event emails still on, no remember-me, no password
#   reset requested), no magic link sent in the last 24 hours;
# - created more than 24 hours ago;
# - NO row anywhere that references them: every foreign key to users (found
#   from the database, so a new table is covered automatically), every
#   `user_id` column, and every polymorphic `*_type`/`*_id` pair pointing at a
#   User. The single exception is their own sign-in records (activity_logs of
#   type login/logout), which record the scanner opening the link; those rows
#   are deleted with the account.
#
# Deletion re-checks each user under a row lock immediately before deleting,
# skips (and reports) anyone who no longer qualifies, and uses delete_all: no
# callbacks, no dependent: :destroy, so it cannot cascade into anyone else's
# data. No foreign key to users cascades, so the database refuses the delete
# outright if anything still references the row.
#
# Output and logs carry user ids and dates only, never an email address.
class UnusedAccounts
  MIN_AGE = 24.hours
  SIGN_IN_ONLY_ACTIVITY = %w[login logout].freeze

  def initialize(created_after: nil, created_before: nil, now: Time.current)
    @created_after = created_after
    @created_before = created_before
    @now = now
  end

  # Every place a row can point at a user: [{ table:, column:, type_column: }].
  # Read from the live schema once per process.
  def self.references
    @references ||= scan_references.freeze
  end

  def self.scan_references
    conn = ActiveRecord::Base.connection
    refs = []
    conn.tables.each do |table|
      conn.foreign_keys(table).each do |fk|
        refs << { table: table, column: fk.column } if fk.to_table == "users"
      end
      columns = conn.columns(table).map(&:name)
      refs << { table: table, column: "user_id" } if table != "users" && columns.include?("user_id")
      columns.grep(/_type\z/).each do |type_col|
        id_col = type_col.sub(/_type\z/, "_id")
        refs << { table: table, column: id_col, type_column: type_col } if columns.include?(id_col)
      end
    end
    refs.uniq
  end

  def candidates
    scope = User.where(<<~SQL.squish, cutoff: @now - MIN_AGE)
      COALESCE(TRIM(users.first_name), '') = '' AND COALESCE(TRIM(users.last_name), '') = ''
      AND COALESCE(TRIM(users.bio), '') = ''
      AND users.password_set_manually = FALSE
      AND COALESCE(users.provider, '') = '' AND COALESCE(users.uid, '') = ''
      AND users.unconfirmed_email IS NULL AND users.email_change_token IS NULL
      AND users.invited_by_id IS NULL AND users.invitation_sent_at IS NULL
      AND users.invitation_accepted_at IS NULL AND users.invitation_token_digest IS NULL
      AND users.admin_role = 'none' AND users.is_admin = FALSE
      AND COALESCE(users.stripe_customer_id, '') = '' AND COALESCE(users.stripe_subscription_id, '') = ''
      AND COALESCE(users.subscription_status, '') = '' AND COALESCE(users.subscription_plan, '') = ''
      AND users.subscription_ends_at IS NULL AND users.subscription_paused_at IS NULL
      AND users.cancel_at_period_end IS NOT TRUE
      AND users.founding_member = FALSE AND users.founding_revoked_at IS NULL
      AND users.credits = 0 AND users.favorites_count = 0
      AND users.otp_enabled IS NOT TRUE AND users.otp_secret_key IS NULL AND users.backup_codes IS NULL
      AND users.event_emails = TRUE
      AND users.remember_created_at IS NULL
      AND users.reset_password_token IS NULL AND users.reset_password_sent_at IS NULL
      AND (users.magic_link_sent_at IS NULL OR users.magic_link_sent_at < :cutoff)
      AND users.created_at < :cutoff
    SQL
    scope = scope.where(created_at: @created_after.in_time_zone.beginning_of_day..) if @created_after
    scope = scope.where(created_at: ...@created_before.in_time_zone.beginning_of_day) if @created_before
    self.class.references.each { |ref| scope = scope.where(not_referenced_sql(ref)) }
    scope.order(:id)
  end

  # Prints the report and, with confirm, deletes. `ids` lets a caller (and the
  # tests) pin the candidate list read earlier; every id is re-checked anyway.
  def run(confirm:, out: $stdout, ids: nil)
    ids ||= candidates.pluck(:id)
    created = User.where(id: ids).order(:id).pluck(:id, :created_at)

    out.puts "#{created.size} unused accounts match#{range_note}."
    unless created.empty?
      out.puts "Created per day:"
      created.group_by { |_, at| at.to_date }.sort.each do |day, rows|
        out.puts format("  %s  %4d", day.iso8601, rows.size)
      end
      created.each { |id, at| out.puts "user #{id}, created #{at.to_date.iso8601}" }
    end

    unless confirm
      Rails.logger.info "[UnusedAccounts] Dry run: #{created.size} candidates, nothing deleted"
      out.puts "Dry run: nothing deleted. Run again with CONFIRM=1 to delete these accounts."
      return { candidates: created.size, deleted: 0, skipped: 0 }
    end

    deleted = []
    skipped = []
    ActiveRecord::Base.transaction do
      created.each do |id, _|
        ActiveRecord::Base.transaction(requires_new: true) do
          if delete_one(id)
            deleted << id
          else
            skipped << id
          end
        end
      rescue ActiveRecord::InvalidForeignKey => e
        Rails.logger.error "[UnusedAccounts] Delete of user #{id} refused by the database (#{e.class}); skipped"
        skipped << id
      end
    end

    skipped.each { |id| out.puts "Skipped user #{id}: it no longer qualifies (activity or identity appeared)" }
    out.puts "Deleted #{deleted.size} unused accounts; skipped #{skipped.size}."
    Rails.logger.info "[UnusedAccounts] Purge finished: deleted #{deleted.size}, skipped #{skipped.size}"
    { candidates: created.size, deleted: deleted.size, skipped: skipped.size }
  end

  private

  # Locks the row, re-checks every criterion, then deletes the user's own
  # sign-in records and the user. Returns false (and deletes nothing) when the
  # user no longer qualifies.
  def delete_one(id)
    user = User.lock.find_by(id: id)
    unless user && candidates.where(id: id).exists?
      Rails.logger.warn "[UnusedAccounts] User #{id} no longer qualifies; skipped"
      return false
    end

    ActivityLog.where(user_id: id, activity_type: SIGN_IN_ONLY_ACTIVITY).delete_all
    User.where(id: id).delete_all
    Rails.logger.info "[UnusedAccounts] Deleted unused user #{id}"
    true
  end

  def not_referenced_sql(ref)
    conn = ActiveRecord::Base.connection
    table = conn.quote_table_name(ref[:table])
    column = "#{table}.#{conn.quote_column_name(ref[:column])}"
    condition = "#{column} = users.id"
    condition += " AND #{table}.#{conn.quote_column_name(ref[:type_column])} = #{conn.quote('User')}" if ref[:type_column]
    if ref[:table] == "activity_logs" && ref[:column] == "user_id"
      types = SIGN_IN_ONLY_ACTIVITY.map { |t| conn.quote(t) }.join(", ")
      condition += " AND #{table}.activity_type NOT IN (#{types})"
    end
    if ref[:table] == "users"
      # Self-reference (users.invited_by_id): another user's row pointing here.
      return "NOT EXISTS (SELECT 1 FROM users AS referencing WHERE referencing.#{conn.quote_column_name(ref[:column])} = users.id)"
    end
    "NOT EXISTS (SELECT 1 FROM #{table} WHERE #{condition})"
  end

  def range_note
    parts = []
    parts << "created on or after #{@created_after.iso8601}" if @created_after
    parts << "created before #{@created_before.iso8601}" if @created_before
    parts.empty? ? "" : " (#{parts.join(', ')})"
  end
end
