class Presentation < ApplicationRecord
  # One number for every deck-image size rule (validations + import filter).
  # Big enough for full-res deck photography; downscaling via libvips is the
  # eventual polish (see SECTION_NOTES).
  MAX_IMAGE_SIZE = 15.megabytes

  belongs_to :author, class_name: 'User'
  has_many :user_presentations, dependent: :destroy
  # Deck reviews (stars + short text; eligibility in PresentationReview).
  # Events that ran this deck keep their record; restrict, don't cascade.
  has_many :presentation_reviews, dependent: :destroy
  has_many :events, dependent: :nullify

  # The cached summary (reviews_count / reviews_average) is what deck cards
  # read, so bulk listings cost no extra queries. Recompute, never increment:
  # one aggregate over the reviews table is the only writer, which keeps the
  # cache self-healing if a row is ever changed out from under us.
  def refresh_review_stats!
    stats = presentation_reviews.pick(Arel.sql("COUNT(*), AVG(rating)"))
    count, average = stats || [0, nil]
    update_columns(reviews_count: count.to_i, reviews_average: average)
    Rails.logger.info "Deck #{id}: review stats refreshed to #{count.to_i} review(s), average #{average&.to_f || 'none'}"
  end

  def average_review_rating
    reviews_average&.to_f
  end

  def reviewed?
    reviews_count.to_i.positive?
  end
  has_many :presentation_tags, dependent: :destroy
  has_many :tags, through: :presentation_tags
  has_many :purchasers, through: :user_presentations, source: :user

  # Active Storage attachments
  has_one_attached :featured_image
  has_one_attached :pdf_file
  has_many_attached :supplemental_materials
  has_many_attached :slide_images   # rendered pages of the deck, in order

  # Specific file types for better organization
  has_one_attached :sneak_peek_file  # Preview version of the presentation
  has_one_attached :speaker_notes     # Speaker notes document
  has_one_attached :outline_file      # Presentation outline
  has_one_attached :recommendations_sheet  # Whiskey recommendations PDF
  has_one_attached :scorecard          # Custom tasting scorecard (optional; buyers always get the blank one too)

  # Validations
  validates :title, presence: true, length: { minimum: 2, maximum: 200 }
  validates :description, length: { maximum: 1000 }
  validates :content, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :category, length: { maximum: 100 }
  validates :difficulty, inclusion: { in: %w[Beginner Intermediate Advanced], allow_blank: true }

  # Publishing gate: a deck cannot go live without the file buyers download
  # and its rendered slide previews (the buyer page leans on the slide strip;
  # publishing mid-render would ship an empty preview). Validated on the
  # draft->published transition only, so unrelated edits to legacy published
  # records don't get stuck.
  validate :ready_to_publish, if: -> { published? && will_save_change_to_published? }

  # File attachment validations
  validate :featured_image_validation
  validate :pdf_file_validation
  validate :supplemental_materials_validation

  # Scopes
  scope :free, -> { where(price: 0) }
  scope :paid, -> { where('price > 0') }
  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :featured, -> { where(featured: true) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :by_difficulty, ->(difficulty) { where(difficulty: difficulty) if difficulty.present? }
  scope :search, ->(query) { where('title ILIKE ? OR description ILIKE ?', "%#{query}%", "%#{query}%") if query.present? }
  scope :by_tag, ->(tag_name) { joins(:tags).where(tags: { name: tag_name }) if tag_name.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { left_joins(:user_presentations).group(:id).order(Arel.sql("COUNT(user_presentations.id) DESC"), created_at: :desc) }

  # Comma-separated tag editing ("smoky, islay, beginner friendly"). Tags are
  # normalized lowercase; find-or-create under the 'deck' tag category.
  def tag_names
    tags.pluck(:name).join(', ')
  end

  def tag_names=(value)
    names = value.to_s.split(',').map { |n| n.strip.downcase }.reject(&:blank?).uniq.first(10)
    self.tags = names.map { |n| Tag.find_or_create_by(name: n) { |t| t.category = 'deck' } }
  end

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

  # Duration as buyers should read it: a bare number means minutes.
  # (Admins type "20" as often as "45 min", don't render naked digits.)
  def duration_label
    return if duration.blank?
    duration.match?(/\A\s*\d+\s*\z/) ? "#{duration.strip} min" : duration
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

  # File access control methods
  def can_view_sneak_peek?(user = nil)
    # Sneak peek is always available to everyone
    true
  end

  def can_download_full_presentation?(user)
    return false unless user
    return true if user.admin?

    # Delegates to the access rule that understands purchase types: direct
    # purchases are forever, credit purchases require an active subscription.
    user.can_access_presentation?(id)
  end

  def can_download_speaker_notes?(user)
    can_download_full_presentation?(user)
  end

  def can_download_outline?(user)
    can_download_full_presentation?(user)
  end

  def can_download_recommendations?(user)
    can_download_full_presentation?(user)
  end

  def increment_download_count!
    increment!(:download_count)
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

  def parsed_whiskey_recommendations
    # Use JSON format if available, otherwise fall back to old format
    if whiskey_recommendations_json.present? && whiskey_recommendations_json.is_a?(Array)
      return whiskey_recommendations_json.map do |rec|
        rec = rec.symbolize_keys
        # Ensure price has $ prefix
        if rec[:price].present?
          rec[:price] = rec[:price].to_s.start_with?('$') ? rec[:price] : "$#{rec[:price]}"
        end
        rec
      end
    end

    # Legacy format support
    return [] if whiskey_recommendations.blank?

    whiskey_recommendations.split("\n").map do |line|
      parts = line.split('|')
      next if parts.length < 4

      price = parts[2].strip
      # Ensure price has $ prefix
      price = price.start_with?('$') ? price : "$#{price}" if price.present?

      {
        name: parts[0].strip,
        region: parts[1].strip,
        price: price,
        style: parts[3].strip,
        notes: parts[4]&.strip
      }
    end.compact
  end

  # Parse what you'll learn into array of points
  def parsed_what_youll_learn
    return [] if what_youll_learn.blank?

    # Split into sections based on lines that start with - followed by a title
    sections = []
    current_title = nil
    current_description = []
    in_section = false

    what_youll_learn.split("\n").each do |line|
      # Check if this is a new section (starts with - and has a title format)
      if line.strip.match(/^[-•*]\s*(.+)$/)
        # Save previous section if exists
        if current_title && in_section
          sections << {
            title: current_title,
            description: current_description.join(" ").strip
          }
        end

        # Start new section
        current_title = $1.strip
        current_description = []
        in_section = true
      elsif line.strip.blank?
        # Blank line - if we're in a section, it might be ending
        if in_section && current_description.any?
          # This blank line ends the current section
          sections << {
            title: current_title,
            description: current_description.join(" ").strip
          }
          current_title = nil
          current_description = []
          in_section = false
        end
      elsif in_section
        # This is part of the description
        current_description << line.strip
      end
    end

    # Don't forget the last section if it wasn't ended by a blank line
    if current_title && in_section
      sections << {
        title: current_title,
        description: current_description.join(" ").strip
      }
    end

    sections
  end

  # Parse slides preview into structured data
  def parsed_slides_preview
    return [] if slides_preview.blank?

    slides_preview.split("\n").map do |line|
      parts = line.split('|')
      next if parts.length < 4

      {
        slide_number: parts[0].strip,
        title: parts[1].strip,
        description: parts[2].strip,
        duration: parts[3].strip
      }
    end.compact
  end

  # Slide previews rendered by DeckSlideRenderJob (LibreOffice, jobs
  # container). The publish gate and admin UI both key off these.
  def slides_rendered?
    slide_images.attached?
  end

  # How many rendered slides a non-buyer sees before the paywall fade.
  # We never reveal the whole deck for free, so this always withholds at least
  # the last slide (capped at total - 1). 0 when nothing is rendered yet; a
  # lone-slide deck shows its one slide (nothing to hold back).
  def effective_preview_slide_count
    total = slide_images.attached? ? slide_images.count : 0
    return 0 if total.zero?
    return 1 if total == 1

    [preview_slide_count || 3, total - 1].min.clamp(1, total - 1)
  end

  def slide_render_pending?
    SolidQueue::Job.where(class_name: "DeckSlideRenderJob", finished_at: nil)
                   .where.not(id: SolidQueue::FailedExecution.select(:job_id))
                   .any? { |job| job.arguments.dig("arguments", 0) == id }
  rescue NameError
    false # Solid Queue absent (e.g. some test setups): treat as no pending render
  end

  private

  def ready_to_publish
    unless pdf_file.attached?
      errors.add(:base, "Attach the deck file (the presentation buyers download) before publishing")
      return
    end

    return if slides_rendered?

    if slide_render_pending?
      errors.add(:base, "Slide previews are still rendering, publish once they finish (usually under a minute)")
    else
      errors.add(:base, "No slide previews have been rendered for this deck, re-render them, then publish")
    end
  end

  def featured_image_validation
    return unless featured_image.attached?

    unless featured_image.content_type.in?(%w[image/jpeg image/jpg image/png image/gif image/webp])
      errors.add(:featured_image, 'must be a valid image format (JPEG, PNG, GIF, or WebP)')
    end

    if featured_image.byte_size > MAX_IMAGE_SIZE
      errors.add(:featured_image, 'must be less than 15MB')
    end
  end

  def pdf_file_validation
    return unless pdf_file.attached?

    allowed_types = [
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation', # .pptx
      'application/vnd.ms-powerpoint' # .ppt
    ]

    unless pdf_file.content_type.in?(allowed_types)
      errors.add(:pdf_file, 'must be a PDF or PowerPoint file')
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
