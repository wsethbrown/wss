# A row on a deck's pour list. THE deck's pour list: there is no second
# storage format any more (the freeform `whiskey_recommendations` string was
# migrated onto this table, see db/migrate/*migrate_written_pours*).
#
# A row is one of two things:
#   - LINKED: it points at a catalog Bottle, which gives the deck page real
#     tasting scores and lets the bottle's page name the decks that call for it.
#   - FREE TEXT: it just carries a name, for a pour that isn't a catalog bottle
#     (a cocktail, or a bottle nobody has entered yet).
#
# The written fields (origin, style, price, notes) stay on the row either way,
# because they are the deck author's recommendation and not properties of the
# bottle. Price especially: it's advice that ages, and two decks can quote
# different prices for the same bottle.
#
# This is what closes the loop the founding story is about: a deck says what
# to pour, a society pours it at a night, and the room's verdict flows back
# to the deck page.
class PresentationBottle < ApplicationRecord
  belongs_to :presentation
  belongs_to :bottle, optional: true

  validates :bottle_id, uniqueness: { scope: :presentation_id, message: "is already on this deck's pour list" },
                        allow_nil: true
  validate :names_the_pour
  # Generous caps: these carry the deck author's prose, not form-field labels.
  validates :name, length: { maximum: 200 }
  validates :price, length: { maximum: 100 }
  validates :origin, :style, length: { maximum: 1000 }
  validates :notes, length: { maximum: 2000 }

  scope :ordered, -> { order(:position, :id) }
  scope :linked, -> { where.not(bottle_id: nil) }

  before_validation :take_next_position, on: :create

  def linked? = bottle_id.present?

  # What the pour list shows. A linked row follows the catalog, so renaming a
  # bottle updates every deck that pours it.
  #
  # `title` is the bare name, for surfaces that show the origin separately (the
  # deck's pour cards). `display_name` appends the distillery to disambiguate
  # two bottles of the same name, for surfaces that show the name alone (admin
  # pickers, search results). Using display_name on a card that also renders
  # origin_text prints the distillery twice.
  def title = bottle&.name.presence || name.to_s

  def display_name = bottle&.display_name.presence || name.to_s

  def origin_text
    return origin if origin.present?

    [ bottle&.distillery, bottle&.region ].compact_blank.join(", ").presence
  end

  def style_text = style.presence || bottle&.style

  private

  def names_the_pour
    return if bottle_id.present? || name.present?

    errors.add(:base, "Give the pour a name, or link it to a catalog bottle")
  end

  def take_next_position
    return if position.present? && position.positive?

    self.position = (presentation&.presentation_bottles&.maximum(:position) || 0) + 1
  end
end
