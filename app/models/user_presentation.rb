class UserPresentation < ApplicationRecord
  belongs_to :user
  belongs_to :presentation
  
  # Purchase types
  PURCHASE_TYPES = %w[direct credit].freeze
  
  validates :purchase_type, inclusion: { in: PURCHASE_TYPES }
  
  scope :direct_purchases, -> { where(purchase_type: 'direct') }
  scope :credit_purchases, -> { where(purchase_type: 'credit') }
  
  def direct_purchase?
    purchase_type == 'direct'
  end
  
  def credit_purchase?
    purchase_type == 'credit'
  end
end
