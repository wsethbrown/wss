# B5 / M1: grants every paying member one deck credit per calendar month.
#
# Stripe sends a renewal invoice only once per billing interval, so before this
# job a yearly member got the welcome credit plus one credit a year. This job
# runs daily (config/recurring.yml) and grants this month's credit to each
# active, unpaused, deck-earning member whose anchor day has arrived and who has
# not had this month's credit yet. The grant itself is idempotent per
# (user, month) in the ledger (CreditTransaction.grant_monthly_credit), so the
# job is safe to run twice, and safe alongside the renewal webhook and the
# admin "grant monthly" button.
#
# The anchor day is the subscription's billing day, read from
# subscription_ends_at (Stripe keeps the period end on the same day of the
# month the subscription started). In a month shorter than the anchor (an
# anchor of the 31st in February) the credit lands on the month's last day.
class MonthlyCreditJob < ApplicationJob
  queue_as :default

  DESCRIPTION = "Monthly subscription credit".freeze
  OWED_PLANS = %w[quarterly yearly].freeze

  def perform
    now = Time.current.utc
    today = now.to_date
    counts = Hash.new(0)

    self.class.candidates.find_each do |user|
      unless self.class.due_on?(user, today)
        counts[:not_yet_due] += 1
        next
      end

      counts[CreditTransaction.grant_monthly_credit(user, DESCRIPTION, at: now)] += 1
    rescue StandardError => e
      counts[:failed] += 1
      Rails.logger.error "MonthlyCreditJob failed for user #{user.id}: #{e.class}: #{e.message}"
    end

    Rails.logger.info "MonthlyCreditJob finished for #{today.strftime('%Y-%m-%d')}: " \
                      "#{counts[:granted]} granted, #{counts[:already_granted]} already had this month's credit, " \
                      "#{counts[:not_yet_due]} not yet due, #{counts[:paused]} paused, " \
                      "#{counts[:society_only]} society-only, #{counts[:inactive]} inactive, #{counts[:failed]} failed"
    counts
  end

  # Members who might be owed a credit. grant_monthly_credit decides (and logs)
  # each one: lapsed, paused and society-only members are counted, not granted.
  def self.candidates
    User.where(subscription_status: "active")
  end

  def self.anchor_day(user) = CreditTransaction.anchor_day(user)

  def self.anchor_date(user, year, month) = CreditTransaction.anchor_date(user, year, month)

  def self.due_on?(user, date)
    date >= anchor_date(user, date.year, date.month)
  end

  # Report only, NEVER grants (owner decision pending on back-pay): for each
  # current quarterly or yearly member, how many monthly credits the new rule
  # would have given them since their current subscription began, against how
  # many they actually received. The start is the member's latest welcome
  # credit (else their first granted credit); members with neither are listed
  # with a nil start so they can be checked by hand in Stripe.
  def self.owed_report(today: Time.current.utc.to_date)
    User.where(subscription_status: "active", subscription_plan: OWED_PLANS).order(:id).map do |user|
      grants = CreditTransaction.where(user: user, transaction_type: CreditTransaction::TRANSACTION_TYPES[:granted])
      start_row = grants.where("description LIKE ?", "Welcome credit%").order(created_at: :desc).first ||
                  grants.order(:created_at).first
      row = { user_id: user.id, plan: user.subscription_plan, since: nil, expected: nil, received: nil, owed: nil }
      next row unless start_row

      since = start_row.created_at.utc.to_date
      expected = expected_grants(user, since, today)
      received = grants.where(created_at: start_row.created_at..).where("amount > 0").count
      row.merge(since: since, expected: expected, received: received, owed: [ expected - received, 0 ].max)
    end
  end

  # Months from the start month (always one: the welcome credit) through
  # today's month, counting today's month only once its anchor day has arrived.
  def self.expected_grants(user, since, today)
    months = (today.year * 12 + today.month) - (since.year * 12 + since.month)
    return 1 if months <= 0

    months + (due_on?(user, today) ? 1 : 0)
  end
end
