class CreditTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :presentation, optional: true

  # The credit_transactions table is the LEDGER and the single source of truth for a
  # user's credit balance. users.credits is a cached total that is recomputed from the
  # ledger (sum of amounts) after every transaction — nothing else may write it.
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

  def self.grant_monthly_credit(user, description = "Monthly subscription credit")
    return unless user.subscription_active?

    record!(user: user, amount: 1, transaction_type: TRANSACTION_TYPES[:granted], description: description)
  end

  WELCOME_DESCRIPTION = "Welcome credit - new subscription".freeze

  # The new-subscriber credit. Idempotent across its two triggers — the
  # checkout success redirect (synchronous, so the credit is visible the
  # moment they land back) and the invoice.payment_succeeded webhook
  # (fallback for closed tabs) — which fire seconds apart. The 24-hour
  # window blocks that double-grant while letting a genuine re-subscriber
  # months later earn a fresh welcome. Returns true if granted.
  def self.grant_welcome_credit(user)
    granted = false
    user.with_lock do
      # Prefix match, not equality: an admin-granted variant ("Welcome
      # credit - new subscription (backfill)") must also count as already
      # welcomed — exact matching once let a manual grant plus the
      # automatic one stack to two credits.
      already = where(user: user, transaction_type: TRANSACTION_TYPES[:granted])
                  .where("description LIKE ?", "Welcome credit%")
                  .where(created_at: 24.hours.ago..).exists?
      unless already
        create!(user: user, amount: 1, transaction_type: TRANSACTION_TYPES[:granted], description: WELCOME_DESCRIPTION)
        granted = true
      end
    end
    granted
  end

  # Spends one credit to grant access to a presentation. Returns true/false.
  def self.use_credit(user, presentation)
    user.with_lock do
      return false unless user.credits.to_i.positive?

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
    true
  rescue ActiveRecord::RecordInvalid
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
