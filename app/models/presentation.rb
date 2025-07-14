class Presentation < ApplicationRecord
  belongs_to :author, class_name: 'User'
  has_many :user_presentations, dependent: :destroy
  has_many :purchasers, through: :user_presentations, source: :user

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, length: { maximum: 1000 }
  validates :content, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :category, length: { maximum: 100 }
  validates :difficulty, inclusion: { in: %w[Beginner Intermediate Advanced], allow_blank: true }
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true

  # Scopes
  scope :free, -> { where(price: 0) }
  scope :paid, -> { where('price > 0') }
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) if difficulty.present? }
  scope :search, ->(query) { where('title ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%") if query.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { order(rating: :desc, review_count: :desc) }

  # Instance methods
  def free?
    price.zero?
  end

  def paid?
    price > 0
  end

  def formatted_price
    return 'Free' if free?
    "$#{price}"
  end

  def excerpt(length = 150)
    return description if description.blank?
    description.length > length ? "#{description[0...length]}..." : description
  end

  def reading_time
    return 0 if content.blank?
    words = content.split.length
    (words / 200.0).ceil # Average reading speed of 200 words per minute
  end
  
  def purchased_by?(user)
    return false unless user
    user_presentations.exists?(user: user)
  end
  
  def purchase_type_for(user)
    return nil unless user
    user_presentations.find_by(user: user)&.purchase_type
  end
  
  def stripe_price_id
    # This would be set via admin or seeded data
    # For now, we'll generate it dynamically
    "price_presentation_#{id}"
  end
  
  def stripe_amount
    (price * 100).to_i # Convert to cents for Stripe
  end
end
