# The society's member ledger (owner-approved, July 2026): every join,
# leave, removal, role change, and invitation event, shown to managers on
# the society Activity page. This is deliberately a QUIET record — bell
# notifications only ring for invitation flows and invite-link joins, so
# public-society admins aren't flooded by churn; everything lands here.
class SocietyActivity < ApplicationRecord
  belongs_to :society
  belongs_to :user
  belongs_to :actor, class_name: "User", optional: true

  ACTIONS = %w[joined left removed role_changed invite_sent invite_accepted invite_declined].freeze
  validates :action, inclusion: { in: ACTIONS }

  scope :recent, -> { order(created_at: :desc) }

  # Never let bookkeeping break the action being recorded.
  def self.record!(society:, user:, action:, actor: nil, detail: nil)
    create!(society: society, user: user, action: action, actor: actor, detail: detail)
  rescue => e
    Rails.logger.error "SocietyActivity skipped (#{action}, society #{society&.id}, user #{user&.id}): #{e.message}"
    nil
  end
end
