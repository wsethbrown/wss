class Bottle < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  has_many :reviews, dependent: :destroy
  has_many :bottle_edits, dependent: :destroy

  has_one_attached :pinned_label_image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 400, 400 ], saver: { quality: 80 }
  end
  has_one_attached :label_image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 400, 400 ], saver: { quality: 80 }
  end

  validates :name, presence: true, length: { maximum: 200 }
  validates :distillery, :region, :style, length: { maximum: 200 }
  validates :abv, numericality: { greater_than: 0, less_than: 100 }, allow_nil: true
  validates :slug, presence: true, uniqueness: true
  validate :label_image_is_valid
  validate :pinned_label_image_is_valid

  before_validation :generate_slug, on: :create

  # Public URLs use the slug ("/bottles/eagle-rare-10-buffalo-trace").
  def to_param = slug

  def self.search(term)
    return none if term.blank? # '%%' would match every bottle

    q = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("bottles.name ILIKE :q OR bottles.distillery ILIKE :q", q: q)
  end

  # Aggregate columns (avg_rating, reviewers) computed in SQL with the SAME
  # latest-per-user semantics as #average_rating, one query for a whole page
  # of rows, and sortable. Rows respond to #avg_rating / #reviewers.
  scope :with_score, -> {
    select("bottles.*, agg.avg_rating, agg.reviewers").joins(<<~SQL)
      LEFT JOIN LATERAL (
        SELECT AVG(latest.rating) AS avg_rating, COUNT(*) AS reviewers
        FROM (
          SELECT DISTINCT ON (user_id) rating
          FROM reviews WHERE reviews.bottle_id = bottles.id
          ORDER BY user_id, created_at DESC, id DESC
        ) latest
      ) agg ON TRUE
    SQL
  }

  SORTS = {
    "top"      => "agg.avg_rating DESC NULLS LAST, bottles.name ASC",
    "reviewed" => "agg.reviewers DESC, bottles.name ASC",
    "az"       => "bottles.name ASC",
    "newest"   => "bottles.created_at DESC"
  }.freeze

  # Aggregated flavor families across every tasting of this bottle,
  # the community's palate, summed from Review#flavor_profile.
  def flavor_profile
    reviews.map(&:flavor_profile).each_with_object(Hash.new(0)) do |profile, sum|
      profile.each { |family, n| sum[family] += n }
    end
  end

  # What people actually paid, outlier-proof: median alone for thin data,
  # the interquartile range ("most paid $45-60") once 4+ prices exist.
  # Region-aware buckets are a possible later refinement.
  def price_summary
    prices = reviews.where.not(price_paid: nil).order(:price_paid).pluck(:price_paid).map(&:to_f)
    return nil if prices.empty?
    return { median: percentile(prices, 0.5), count: prices.size } if prices.size < 4

    { low: percentile(prices, 0.25), high: percentile(prices, 0.75), count: prices.size }
  end

  # The community's most-used descriptor words across this bottle's
  # tastings, the left rail's tag cloud.
  def top_descriptors(limit = 5)
    reviews.flat_map { |r| r.descriptor_tags.keys }.tally
           .sort_by { |word, n| [ -n, word ] }.first(limit).map(&:first)
  end

  def display_name
    [ name, distillery ].compact_blank.join(" · ")
  end

  # The public score: each reviewer counts once, via their latest tasting
  # (re-tastes at events arrive in Phase 2 and refresh their contribution).
  def average_rating
    latest_per_user.average(:rating)&.to_f&.round(2)
  end

  def reviewer_count
    reviews.distinct.count(:user_id)
  end

  # Each PUBLIC society's collective take on this bottle, from its event
  # reviews, same latest-per-member math as the society board, so a
  # re-taster refreshes their contribution instead of double-voting.
  # Rows respond to #verdict_avg / #verdict_reviewers.
  def society_verdicts
    latest_per_member = <<~SQL
      INNER JOIN (
        SELECT DISTINCT ON (reviews.user_id, events.society_id) reviews.id
        FROM reviews
        INNER JOIN events ON events.id = reviews.event_id
        WHERE reviews.bottle_id = #{id.to_i}
        ORDER BY reviews.user_id, events.society_id, reviews.created_at DESC, reviews.id DESC
      ) latest ON latest.id = reviews.id
    SQL
    Society.public_societies
      .joins(events: :reviews).joins(latest_per_member)
      .where(reviews: { bottle_id: id })
      .select("societies.*, AVG(reviews.rating) AS verdict_avg, COUNT(DISTINCT reviews.user_id) AS verdict_reviewers")
      .group("societies.id")
      .order(Arel.sql("verdict_avg DESC, societies.name ASC"))
  end

  # /bottles/<slug> image: pin > top-rated review hero (ties: votes, newest)
  # > creator's label_image > nil (view falls back to the SVG placeholder).
  def display_image
    # Memoized, every call site checks presence then renders, and the lookup
    # costs two queries. defined? because nil (imageless bottle) is a valid
    # cached answer.
    return @display_image if defined?(@display_image)

    @display_image =
      if pinned_label_image.attached?
        pinned_label_image
      else
        candidate = reviews.joins(:images_attachments)
                            .distinct
                            .order(rating: :desc, votes_count: :desc, created_at: :desc)
                            .first
        candidate&.hero_image || (label_image.attached? ? label_image : nil)
      end
  end

  # Sets the same memo #display_image reads, lets batch preloading (see
  # .preload_display_images) hand a bottle its precomputed answer so the
  # reader never falls through to the per-bottle query path. nil is a valid
  # assigned value (imageless bottle), same as the lazy path.
  def display_image=(img)
    @display_image = img
  end

  # Batch version of #display_image for list pages: one query to find each
  # bottle's top review-with-images (same DISTINCT ON tie-break order as the
  # instance method, rating desc, votes_count desc, created_at desc), one
  # query to preload those candidate reviews' image attachments, then an
  # in-memory walk assigning each bottle's memoized #display_image.
  #
  # Callers must preload pinned_label_image/label_image attachments on the
  # collection themselves (e.g. .with_attached_pinned_label_image
  # .with_attached_label_image) so the attached? checks below don't query.
  def self.preload_display_images(bottles)
    bottles = bottles.to_a
    return bottles if bottles.empty?

    ids = bottles.map(&:id)

    candidates_by_bottle_id =
      Review.joins(:images_attachments)
            .where(bottle_id: ids)
            .select("DISTINCT ON (reviews.bottle_id) reviews.*")
            .order("reviews.bottle_id, reviews.rating DESC, reviews.votes_count DESC, reviews.created_at DESC")
            .index_by(&:bottle_id)

    ActiveRecord::Associations::Preloader.new(
      records: candidates_by_bottle_id.values,
      associations: { images_attachments: :blob }
    ).call

    bottles.each do |bottle|
      bottle.display_image =
        if bottle.pinned_label_image.attached?
          bottle.pinned_label_image
        else
          candidate = candidates_by_bottle_id[bottle.id]
          candidate&.hero_image || (bottle.label_image.attached? ? bottle.label_image : nil)
        end
    end

    bottles
  end

  private

  # Both label attachments share Review's image rules: same size cap, same
  # allowed types. Any signed-in user can upload label_image (add-a-bottle
  # form), so it needs the same guardrails as review photos.
  def label_image_is_valid
    validate_image_attachment(:label_image, label_image)
  end

  def pinned_label_image_is_valid
    validate_image_attachment(:pinned_label_image, pinned_label_image)
  end

  def validate_image_attachment(attribute, attachment)
    return unless attachment.attached?

    unless attachment.content_type.in?(Review::ALLOWED_IMAGE_TYPES)
      errors.add(attribute, "must be an image (JPEG, PNG, GIF, or WEBP)")
    end
    if attachment.byte_size > Review::MAX_IMAGE_SIZE
      errors.add(attribute, "must be #{Review::MAX_IMAGE_SIZE / 1.megabyte}MB or smaller")
    end
  end

  def percentile(sorted, p)
    idx = (sorted.size - 1) * p
    lo, hi = sorted[idx.floor], sorted[idx.ceil]
    lo + (hi - lo) * (idx - idx.floor)
  end

  def latest_per_user
    reviews.where(
      id: reviews.select("DISTINCT ON (user_id) id").order(:user_id, created_at: :desc, id: :desc)
    )
  end

  def generate_slug
    return if slug.present? || name.blank?

    base = [ name, distillery ].compact_blank.join(" ").parameterize
    candidate = base
    n = 1
    candidate = "#{base}-#{n += 1}" while Bottle.exists?(slug: candidate)
    self.slug = candidate
  end
end
