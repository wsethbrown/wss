class Presentation < ApplicationRecord
  belongs_to :author, class_name: 'User'

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, length: { maximum: 1000 }
  validates :content, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :category, length: { maximum: 100 }

  # Scopes
  scope :free, -> { where(price: 0) }
  scope :paid, -> { where('price > 0') }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :search, ->(query) { where('title ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%") if query.present? }
  scope :recent, -> { order(created_at: :desc) }

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
end
