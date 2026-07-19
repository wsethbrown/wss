# A deck's pour list row, pointing at a real catalog Bottle (Phase 3 "deck
# ties" in the review-system spec). Deliberately mirrors EventBottle: the
# same ordered/labelled shape, so the two pour lists read alike.
#
# This is what closes the loop the founding story is about: a deck says what
# to pour, a society pours it at a night, and the room's verdict flows back
# to the deck page.
class PresentationBottle < ApplicationRecord
  belongs_to :presentation
  belongs_to :bottle

  validates :bottle_id, uniqueness: { scope: :presentation_id, message: "is already on this deck's pour list" }

  scope :ordered, -> { order(:position, :id) }
end
