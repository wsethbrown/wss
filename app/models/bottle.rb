class Bottle < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  has_many :reviews, dependent: :destroy

  validates :name, presence: true, length: { maximum: 200 }
  validates :distillery, :region, :style, length: { maximum: 200 }
  validates :abv, numericality: { greater_than: 0, less_than: 100 }, allow_nil: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  # Public URLs use the slug ("/bottles/eagle-rare-10-buffalo-trace").
  def to_param = slug

  def self.search(term)
    q = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("bottles.name ILIKE :q OR bottles.distillery ILIKE :q", q: q)
  end

  def display_name
    [name, distillery].compact_blank.join(" — ")
  end

  # The public score: each reviewer counts once, via their latest tasting
  # (re-tastes at events arrive in Phase 2 and refresh their contribution).
  def average_rating
    latest_per_user.average(:rating)&.to_f&.round(2)
  end

  def reviewer_count
    reviews.distinct.count(:user_id)
  end

  private

  def latest_per_user
    reviews.where(
      id: reviews.select("DISTINCT ON (user_id) id").order(:user_id, created_at: :desc, id: :desc)
    )
  end

  def generate_slug
    return if slug.present? || name.blank?

    base = [name, distillery].compact_blank.join(" ").parameterize
    candidate = base
    n = 1
    candidate = "#{base}-#{n += 1}" while Bottle.exists?(slug: candidate)
    self.slug = candidate
  end
end
