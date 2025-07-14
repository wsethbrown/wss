class Presentation < ApplicationRecord
  belongs_to :author, class_name: 'User'
  has_many :user_presentations, dependent: :destroy
  has_many :purchasers, through: :user_presentations, source: :user
  
  # Active Storage attachments
  has_one_attached :featured_image
  has_one_attached :pdf_file
  has_many_attached :supplemental_materials

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, length: { maximum: 1000 }
  validates :content, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :category, length: { maximum: 100 }
  validates :difficulty, inclusion: { in: %w[Beginner Intermediate Advanced], allow_blank: true }
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  
  # File attachment validations
  validate :featured_image_validation
  validate :pdf_file_validation
  validate :supplemental_materials_validation

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
  
  private
  
  def featured_image_validation
    return unless featured_image.attached?
    
    unless featured_image.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
      errors.add(:featured_image, 'must be a valid image format (JPEG, PNG, GIF, or WebP)')
    end
    
    if featured_image.byte_size > 5.megabytes
      errors.add(:featured_image, 'must be less than 5MB')
    end
  end
  
  def pdf_file_validation
    return unless pdf_file.attached?
    
    unless pdf_file.content_type == 'application/pdf'
      errors.add(:pdf_file, 'must be a PDF file')
    end
    
    if pdf_file.byte_size > 50.megabytes
      errors.add(:pdf_file, 'must be less than 50MB')
    end
  end
  
  def supplemental_materials_validation
    return unless supplemental_materials.attached?
    
    supplemental_materials.each do |material|
      unless material.content_type.in?(%w[application/pdf image/jpeg image/jpg image/png application/vnd.ms-powerpoint application/vnd.openxmlformats-officedocument.presentationml.presentation])
        errors.add(:supplemental_materials, 'must be PDF, image, or PowerPoint files')
      end
      
      if material.byte_size > 25.megabytes
        errors.add(:supplemental_materials, 'files must be less than 25MB each')
      end
    end
  end
end
