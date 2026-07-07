class Review < ApplicationRecord
  VALID_RATINGS = (1..10).map { |n| n / 2.0 }.freeze # 0.5 .. 5.0 in half steps

  belongs_to :user
  belongs_to :bottle
  belongs_to :event, optional: true

  validates :rating, presence: true, inclusion: { in: VALID_RATINGS }
  validates :notes, length: { maximum: 5_000 }
  validates :price_paid, numericality: { greater_than: 0, less_than: 100_000 }, allow_nil: true
  validates :nose, :palate, :finish, :body_notes, length: { maximum: 500 }
  validates :bottle_id, uniqueness: {
    scope: [:user_id, :event_id],
    message: "already has your review — edit it instead"
  }
  validate :event_review_gates, on: :create, if: -> { event.present? }

  scope :recent_first, -> { order(created_at: :desc) }

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

  WORD_TO_FAMILY = DESCRIPTOR_LEXICON.flat_map { |fam, words| words.map { |w| [w, fam] } }.to_h.freeze

  def tasting_text
    [nose, palate, finish, body_notes].compact_blank.join(" ")
  end

  # => { "peat" => "smoky", "honey" => "sweet", ... } for words present.
  def descriptor_tags
    words = tasting_text.downcase.scan(/[a-z]+/)
    words.uniq.filter_map { |w| [w, WORD_TO_FAMILY[w]] if WORD_TO_FAMILY.key?(w) }.to_h
  end

  # Hand-set wheel intensities win over word counts: the reviewer said so.
  def wheel_values
    flavor_wheel.to_h.filter_map { |fam, v|
      [fam, v.to_f.clamp(0.0, 1.0)] if DESCRIPTOR_LEXICON.key?(fam) && v.to_f.positive?
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

  # Reviews whose tasting text mentions EVERY given tag. A tag may be a
  # descriptor word ("peat") or a whole family ("smoky" = any of its words).
  scope :tagged, ->(tags) {
    Array(tags).reduce(all) do |rel, tag|
      tag = tag.to_s.downcase.strip
      words = DESCRIPTOR_LEXICON.key?(tag) ? DESCRIPTOR_LEXICON[tag] | [tag] : [tag]
      pattern = '\\m(' + words.map { |w| Regexp.escape(w) }.join("|") + ")"
      rel.where("concat_ws(' ', nose, palate, finish, body_notes) ~* ?", pattern)
    end
  }

  private

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
