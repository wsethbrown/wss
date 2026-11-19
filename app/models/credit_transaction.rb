class CreditTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :presentation, optional: true

  # The credit_transactions table is the LEDGER and the single source of truth for a
  # user's credit balance. users.credits is a cached total that is recomputed from the
  # ledger (sum of amounts) after every transaction, nothing else may write it.
  TRANSACTION_TYPES = {
    granted: "granted",                    # subscription activation, monthly refresh
    used: "used",                          # spent on a presentation
    expired: "expired",                    # removed when a subscription ends
    refunded: "refunded",                  # returned on refund
    admin_adjustment: "admin_adjustment"   # manual correction by an admin
  }.freeze

  validates :transaction_type, presence: true, inclusion: { in: TRANSACTION_TYPES.values }
  validates :amount, presence: true, numericality: { only_integer: true }

  scope :granted, -> { where(transaction_type: TRANSACTION_TYPES[:granted]) }
  scope :used, -> { where(transaction_type: TRANSACTION_TYPES[:used]) }
  scope :expired, -> { where(transaction_type: TRANSACTION_TYPES[:expired]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_presentation, ->(presentation) { where(presentation: presentation) }

  after_create :recompute_cached_balance

  # The ledger is append-only (B7 / M20): a persisted row is never edited or
  # deleted; corrections are new rows (Admin -> Credits -> adjust). This guards
  # the model layer (update, destroy and dependent: cascades raise); raw SQL
  # and delete_all can still bypass it.
  def readonly?
    persisted? || super
  end

  # --- Ledger API ---------------------------------------------------------
  # Every credit change goes through here. Locks the user row so concurrent
  # grants/spends can't race the cached balance.
  def self.record!(user:, amount:, transaction_type:, description: nil, presentation: nil)
    user.with_lock do
      create!(
        user: user,
        amount: amount,
        transaction_type: transaction_type,
        description: description,
        presentation: presentation
      )
    end
  end

  # --- Monthly credit (B5 / M1) -------------------------------------------
  # One deck credit per member per CALENDAR month, on every plan. Stripe only
  # sends a renewal invoice once per billing interval (once a year on yearly),
  # so the daily MonthlyCreditJob grants the months in between. The job, the
  # renewal webhook, the admin "grant monthly" button and the welcome credit
  # all share one ledger key per (user, month), checked under the user's row
  # lock and backed by a unique index, so no path can double-grant.
  #
  # The key names the member's BILLING month: the month of the latest anchor
  # date (their billing day, see anchor_date) on or before the grant. In steady
  # state each anchor date falls in its own calendar month, so this is one
  # credit per calendar month; but a renewal for the Feb 28 period that settles
  # just after midnight on Mar 1 still counts as February's credit instead of
  # taking March's (which once left a 58-day gap until the next credit).
  def self.monthly_grant_key(user, at = Time.current)
    "monthly:#{user.id}:#{billing_month(user, at).strftime('%Y-%m')}"
  end

  # Day of the month the member's billing renews on; the 1st when unknown.
  # Stripe keeps the period end on the billing day of the month.
  def self.anchor_day(user)
    user.subscription_ends_at&.utc&.day || 1
  end

  # The anchor date in a given month, clamped to the month's last day (an
  # anchor of the 31st falls on Feb 28 and Apr 30).
  def self.anchor_date(user, year, month)
    Date.new(year, month, [ anchor_day(user), Date.new(year, month, -1).day ].min)
  end

  # First day of the month holding the latest anchor date on or before `at`.
  def self.billing_month(user, at = Time.current)
    date = at.utc.to_date
    date = date.prev_month if date < anchor_date(user, date.year, date.month)
    date.beginning_of_month
  end

  def self.monthly_credit_granted?(user, at = Time.current)
    exists?(grant_key: monthly_grant_key(user, at))
  end

  # Grants this month's credit if the member is due one. Returns a symbol saying
  # what happened: :granted, :already_granted, :inactive, :society_only or :paused.
  # Every no-op is logged, so a missing credit is explainable from the logs.
  def self.grant_monthly_credit(user, description = "Monthly subscription credit", at: Time.current)
    outcome =
      if !user.subscription_active?
        :inactive
      elsif user.society_only_plan?
        # The $5 founding society-only plan runs societies; it earns NO deck credits.
        :society_only
      elsif user.subscription_paused?
        # A paused member pays nothing, so earns nothing until they resume.
        :paused
      end

    if outcome
      Rails.logger.info "Monthly credit not granted to user #{user.id}: #{outcome} (status #{user.subscription_status.inspect}, plan #{user.subscription_plan.inspect})"
      return outcome
    end

    key = monthly_grant_key(user, at)
    outcome = :already_granted
    user.with_lock do
      unless exists?(grant_key: key)
        create!(user: user, amount: 1, transaction_type: TRANSACTION_TYPES[:granted],
                description: description, grant_key: key)
        outcome = :granted
      end
    end

    if outcome == :granted
      Rails.logger.info "Monthly credit granted to user #{user.id} (#{key}): #{description}"
    else
      Rails.logger.info "Monthly credit already granted to user #{user.id} (#{key}); skipping"
    end
    outcome
  rescue ActiveRecord::RecordNotUnique
    # A concurrent grant won the race between our check and insert; the unique
    # index kept it to one row.
    Rails.logger.info "Monthly credit already granted to user #{user.id} (#{key}); lost a concurrent race"
    :already_granted
  end

  WELCOME_DESCRIPTION = "Welcome credit - new subscription".freeze

  # The new-subscriber credit. Idempotent across its two triggers, the
  # checkout success redirect (synchronous, so the credit is visible the
  # moment they land back) and the invoice.payment_succeeded webhook
  # (fallback for closed tabs), which fire seconds apart. The 24-hour
  # window blocks that double-grant while letting a genuine re-subscriber
  # months later earn a fresh welcome. Returns true if granted.
  #
  # The welcome credit IS the first month's credit: it takes this month's
  # monthly grant key, so the daily job does not grant again on the same day.
  # If a monthly credit already landed in the last 24 hours (the job ran
  # between activation and the welcome trigger) that counts as the welcome.
  # A re-subscriber whose month key was used earlier in the month (before a
  # cancel) still gets a welcome, recorded without a key.
  def self.grant_welcome_credit(user)
    # Society-only founding members get no deck credits, welcome included.
    # Guarded here so BOTH triggers (sync redirect + webhook) are covered.
    if user.society_only_plan?
      Rails.logger.info "Welcome credit not granted to user #{user.id}: society-only plan"
      return false
    end

    key = monthly_grant_key(user)
    granted = false
    user.with_lock do
      # Prefix match, not equality: an admin-granted variant ("Welcome
      # credit - new subscription (backfill)") must also count as already
      # welcomed, exact matching once let a manual grant plus the
      # automatic one stack to two credits.
      recent = where(user: user, transaction_type: TRANSACTION_TYPES[:granted]).where(created_at: 24.hours.ago..)
      already = recent.where("description LIKE ?", "Welcome credit%").exists? || recent.where(grant_key: key).exists?
      unless already
        key_free = !exists?(grant_key: key)
        create!(user: user, amount: 1, transaction_type: TRANSACTION_TYPES[:granted],
                description: WELCOME_DESCRIPTION, grant_key: (key if key_free))
        granted = true
      end
    end
    Rails.logger.info "Welcome credit #{granted ? 'granted to' : 'already granted to'} user #{user.id}"
    granted
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info "Welcome credit for user #{user.id} lost a concurrent race for #{key}; already granted"
    false
  end

  # Spends one credit to grant access to a presentation. Returns true/false.
  # The ownership re-check runs inside the user's row lock, so a double-click
  # (or two tabs) cannot spend two credits on one deck; the unique index on
  # user_presentations is the backstop and rolls the whole spend back.
  def self.use_credit(user, presentation)
    user.with_lock do
      unless user.credits.to_i.positive?
        Rails.logger.info "Credit not spent by user #{user.id} on presentation #{presentation.id}: no credits"
        return false
      end

      if UserPresentation.owned?(user, presentation)
        Rails.logger.warn "Credit not spent by user #{user.id} on presentation #{presentation.id}: deck already owned"
        return false
      end

      create!(
        user: user,
        presentation: presentation,
        transaction_type: TRANSACTION_TYPES[:used],
        amount: -1,
        description: "Used for: #{presentation.title}"
      )

      user.user_presentations.create!(
        presentation: presentation,
        purchase_type: "credit",
        purchased_at: Time.current
      )
    end
    Rails.logger.info "Credit spent by user #{user.id} on presentation #{presentation.id}"
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Credit spend failed for user #{user.id}, presentation #{presentation.id}: #{e.message}"
    false
  rescue ActiveRecord::RecordNotUnique
    # A concurrent unlock won; the transaction rolled back, so no credit left.
    Rails.logger.warn "Credit spend by user #{user.id} on presentation #{presentation.id} lost a race to an existing ownership row; rolled back"
    false
  end

  def self.expire_all_credits(user, reason = "Subscription ended")
    user.with_lock do
      balance = user.credits.to_i
      return if balance.zero?

      create!(
        user: user,
        transaction_type: TRANSACTION_TYPES[:expired],
        amount: -balance,
        description: reason
      )
    end
  end

  # Cached balance derived straight from the ledger. Use for reconciliation checks.
  def self.balance_for(user)
    where(user: user).sum(:amount)
  end

  private

  # The ONLY place users.credits is written. Recomputing from the ledger sum makes the
  # cache self-healing and guarantees credits == sum(credit_transactions.amount).
  def recompute_cached_balance
    user.update_column(:credits, user.credit_transactions.sum(:amount))
  end
end
