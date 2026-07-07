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

  private

  def generate_slug
    return if slug.present? || name.blank?

    base = [name, distillery].compact_blank.join(" ").parameterize
    candidate = base
    n = 1
    candidate = "#{base}-#{n += 1}" while Bottle.exists?(slug: candidate)
    self.slug = candidate
  end
end
