class UserPresentation < ApplicationRecord
  belongs_to :user
  belongs_to :presentation

  # Purchase types
  PURCHASE_TYPES = %w[direct credit].freeze

  validates :purchase_type, inclusion: { in: PURCHASE_TYPES }

  scope :direct_purchases, -> { where(purchase_type: "direct") }
  scope :credit_purchases, -> { where(purchase_type: "credit") }

  # True when the user already has an ownership row for the deck. The
  # credit-spend path calls this inside the user's row lock.
  def self.owned?(user, presentation)
    exists?(user_id: user.id, presentation_id: presentation.id)
  end

  def direct_purchase?
    purchase_type == "direct"
  end

  def credit_purchase?
    purchase_type == "credit"
  end
end
