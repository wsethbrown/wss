class CreditTransaction < ApplicationRecord
  belongs_to :user
  belongs_to :presentation, optional: true
  
  # Transaction types
  TRANSACTION_TYPES = {
    granted: 'granted',      # Credits given (subscription activation, monthly refresh)
    used: 'used',           # Credits spent on presentations
    expired: 'expired',     # Credits removed (subscription cancellation)
    refunded: 'refunded'    # Credits returned (purchase refund)
  }.freeze
  
  validates :transaction_type, presence: true, inclusion: { in: TRANSACTION_TYPES.values }
  validates :amount, presence: true, numericality: { integer: true }
  validates :user, presence: true
  
  # Scopes
  scope :granted, -> { where(transaction_type: TRANSACTION_TYPES[:granted]) }
  scope :used, -> { where(transaction_type: TRANSACTION_TYPES[:used]) }
  scope :expired, -> { where(transaction_type: TRANSACTION_TYPES[:expired]) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_presentation, ->(presentation) { where(presentation: presentation) }
  
  # Callbacks
  after_create :update_user_credit_balance
  
  # Class methods
  def self.grant_monthly_credit(user, description = "Monthly subscription credit")
    return unless user.subscription_active?
    
    create!(
      user: user,
      transaction_type: TRANSACTION_TYPES[:granted],
      amount: 1,
      description: description
    )
  end
  
  def self.use_credit(user, presentation)
    return false unless user.credits > 0
    
    transaction do
      create!(
        user: user,
        presentation: presentation,
        transaction_type: TRANSACTION_TYPES[:used],
        amount: -1,
        description: "Used for: #{presentation.title}"
      )
      
      user.user_presentations.create!(
        presentation: presentation,
        purchase_type: 'credit',
        purchased_at: Time.current
      )
    end
    
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
  
  def self.expire_all_credits(user, reason = "Subscription ended")
    return if user.credits == 0
    
    create!(
      user: user,
      transaction_type: TRANSACTION_TYPES[:expired],
      amount: -user.credits,
      description: reason
    )
  end
  
  private
  
  def update_user_credit_balance
    user.increment!(:credits, amount)
  end
end