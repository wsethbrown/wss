class Review < ApplicationRecord
  VALID_RATINGS = (1..10).map { |n| n / 2.0 }.freeze # 0.5 .. 5.0 in half steps
  MAX_IMAGES = 3
  MAX_IMAGE_SIZE = 15.megabytes
  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/jpg image/png image/gif image/webp].freeze

  belongs_to :user
  belongs_to :bottle
  belongs_to :event, optional: true
  has_many :review_votes, dependent: :destroy

  has_many_attached :images do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 400, 400 ], saver: { quality: 80 }
  end

  validates :rating, presence: true, inclusion: { in: VALID_RATINGS }
  validates :notes, length: { maximum: 5_000 }
  validates :price_paid, numericality: { greater_than: 0, less_than: 100_000 }, allow_nil: true
  validates :nose, :palate, :finish, :body_notes, length: { maximum: 500 }
  validates :bottle_id, uniqueness: {
    scope: [ :user_id, :event_id ],
    message: "already has your review — edit it instead"
  }
  validate :event_review_gates, on: :create, if: -> { event.present? }
  validate :images_are_valid

  scope :recent_first, -> { order(created_at: :desc) }

  # The "Tasting nights" feed: reviews poured at PUBLIC societies' events.
  # Private societies stay veiled — their nights are never sourceable here,
  # matching the provenance-card veiling rule.
  scope :from_tasting_nights, ->(society: nil) {
    scoped = joins(event: :society).where(societies: { is_private: false })
    scoped = scoped.where(events: { society_id: society.id }) if society
    scoped
  }

  # Tastings ranked by thumbs-up received in the trailing window — a delta
  # ranking, distinct from the lifetime votes_count counter cache used on
  # bottle pages. LEFT JOIN keeps zero-vote reviews (sorted last); ties break
  # newest-first per the addendum.
  def self.hot_ranked(since: 30.days.ago, limit: 30)
    select("reviews.*, COUNT(recent_votes.id) AS recent_votes_count")
      .joins("LEFT JOIN review_votes recent_votes ON recent_votes.review_id = reviews.id AND recent_votes.created_at >= #{connection.quote(since)}")
      .group("reviews.id")
      .order("recent_votes_count DESC, reviews.created_at DESC")
      .includes(:user, :bottle, event: [ :society, :event_bottles ])
      .limit(limit)
  end

  # Reviews from bookmarked people/societies: latest by favorited users, plus
  # reviews tied to favorited societies' events. Deduped.
  def self.for_circle(user, limit: 5)
    user_ids, society_ids = user.favorited_users.ids, user.favorited_societies.ids
    return none if user_ids.empty? && society_ids.empty?

    review_ids = []
    review_ids.concat(where(user_id: user_ids).pluck(:id)) if user_ids.any?
    review_ids.concat(joins(:event).where(events: { society_id: society_ids }).pluck(:id)) if society_ids.any?

    return none if review_ids.empty?

    where(id: review_ids.uniq).includes(:user, :bottle, event: [ :society, :event_bottles ]).recent_first.limit(limit)
  end

  # A tasting outside any event.
  def solo? = event_id.nil?

  # ── Flavor descriptors ──────────────────────────────────────────────────
  # The tasting fields are free text; this curated lexicon lifts known
  # descriptor words out of them, each belonging to a flavor family. Tags are
  # computed, never stored — the text stays the source of truth.
  DESCRIPTOR_LEXICON = {
    "smoky"   => %w[peat peaty smoke smoky campfire ash char tar iodine bonfire],
    "sweet"   => %w[honey caramel toffee vanilla chocolate butterscotch molasses sweet sugar maple],
    "fruity"  => %w[cherry apple pear citrus orange lemon berry berries raisin fig plum apricot banana tropical fruit fruity],
    "spicy"   => %w[pepper peppery spice spicy cinnamon clove ginger nutmeg rye anise],
    "floral"  => %w[floral heather rose lavender blossom perfume],
    "oaky"    => %w[oak oaky wood woody cedar tannin barrel resin],
    "grainy"  => %w[malt malty grain cereal biscuit bread corn dough],
    "coastal" => %w[brine briny salt salty sea maritime seaweed mineral],
    "rich"    => %w[leather tobacco coffee nut nutty almond walnut earthy cocoa espresso]
  }.freeze

  WORD_TO_FAMILY = DESCRIPTOR_LEXICON.flat_map { |fam, words| words.map { |w| [ w, fam ] } }.to_h.freeze

  def tasting_text
    [ nose, palate, finish, body_notes ].compact_blank.join(" ")
  end

  # The room's shared vocabulary: most common lexicon words per tasting
  # section across a set of reviews (each review counts a word once, so one
  # wordy taster can't dominate). => { "Nose" => ["peat", "iodine"], ... },
  # sections with no lexicon hits omitted. Powers society verdict cards.
  def self.common_descriptors(reviews, per_section: 4)
    { "Nose" => :nose, "Palate" => :palate, "Finish" => :finish, "Body" => :body_notes }
      .filter_map { |label, attr|
        tally = reviews.flat_map { |r|
          r.public_send(attr).to_s.downcase.scan(/[a-z]+/).uniq.select { |w| WORD_TO_FAMILY.key?(w) }
        }.tally
        [ label, tally.sort_by { |word, count| [ -count, word ] }.first(per_section).map(&:first) ] if tally.any?
      }.to_h
  end

  # => { "peat" => "smoky", "honey" => "sweet", ... } for words present.
  def descriptor_tags
    words = tasting_text.downcase.scan(/[a-z]+/)
    words.uniq.filter_map { |w| [ w, WORD_TO_FAMILY[w] ] if WORD_TO_FAMILY.key?(w) }.to_h
  end

  # Hand-set wheel intensities win over word counts: the reviewer said so.
  def wheel_values
    flavor_wheel.to_h.filter_map { |fam, v|
      [ fam, v.to_f.clamp(0.0, 1.0) ] if DESCRIPTOR_LEXICON.key?(fam) && v.to_f.positive?
    }.to_h
  end

  # => { "smoky" => 3, "sweet" => 1 } — strength per family, for the wheel.
  def flavor_profile
    wheel = wheel_values
    # Scale 0..1 dial values into pseudo-counts so wheels and waves mix
    # hand-set and word-derived tastings on one axis.
    return wheel.transform_values { |v| (v * 3).round(2) } if wheel.any?

    words = tasting_text.downcase.scan(/[a-z]+/)
    words.filter_map { |w| WORD_TO_FAMILY[w] }.tally
  end

  # 0..1 intensity per family for drawing: the hand-set wheel verbatim when
  # present, otherwise word counts normalized against the strongest family.
  def wheel_display_profile
    wheel = wheel_values
    return wheel if wheel.any?

    counts = flavor_profile
    return {} if counts.empty?
    max = counts.values.max.to_f
    counts.transform_values { |n| (n / max).round(3) }
  end

  # The room's shared palate: mean of each member's wheel profile per
  # family, renormalized so the strongest family fills its spoke. Powers
  # the wheel on society verdict cards.
  def self.blended_wheel(reviews)
    profiles = reviews.map(&:wheel_display_profile).reject(&:empty?)
    return {} if profiles.empty?

    sums = Hash.new(0.0)
    profiles.each { |p| p.each { |family, v| sums[family] += v } }
    means = sums.transform_values { |v| v / profiles.size }
    max = means.values.max
    means.transform_values { |v| (v / max).round(3) }
  end

  # Reviews whose tasting text mentions EVERY given tag. A tag may be a
  # descriptor word ("peat") or a whole family ("smoky" = any of its words).
  scope :tagged, ->(tags) {
    Array(tags).reduce(all) do |rel, tag|
      tag = tag.to_s.downcase.strip
      words = DESCRIPTOR_LEXICON.key?(tag) ? DESCRIPTOR_LEXICON[tag] | [ tag ] : [ tag ]
      pattern = '\\m(' + words.map { |w| Regexp.escape(w) }.join("|") + ")"
      rel.where("concat_ws(' ', nose, palate, finish, body_notes) ~* ?", pattern)
    end
  }

  # First upload wins — shown on the review page and feeds Bottle#display_image.
  def hero_image
    images.attached? ? images.first : nil
  end

  private

  def images_are_valid
    return unless images.attached?

    errors.add(:images, "can have at most #{MAX_IMAGES} photos") if images.size > MAX_IMAGES
    images.each do |image|
      errors.add(:images, "must be an image (JPEG, PNG, GIF, or WEBP)") unless image.content_type.in?(ALLOWED_IMAGE_TYPES)
      errors.add(:images, "each photo must be #{MAX_IMAGE_SIZE / 1.megabyte}MB or smaller") if image.byte_size > MAX_IMAGE_SIZE
    end
  end

  # Event reviews are the society's record of the night — they only exist for
  # bottles that were actually poured, written by people who actually said
  # they were going, once the pour list is public knowledge. Create-only:
  # edits never re-check (a deleted RSVP must not brick an existing review),
  # and ReviewsController's strong params can't move a review between events.
  def event_review_gates
    unless event.event_bottles.exists?(bottle_id: bottle_id)
      errors.add(:base, "That bottle isn't on this event's pour list")
    end
    unless event.pours_revealed?
      errors.add(:base, "The pours haven't been revealed yet")
    end
    unless event.event_rsvps.exists?(user_id: user_id, status: "yes")
      errors.add(:base, %(Only members who RSVP'd "going" can review this event's pours))
    end
  end
end
