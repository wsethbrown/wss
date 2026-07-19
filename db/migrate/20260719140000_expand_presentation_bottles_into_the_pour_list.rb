# One pour list per deck.
#
# `presentations.whiskey_recommendations` (a pipe-delimited string) and
# `presentation_bottles` (catalog links) were two storage formats for the same
# concept, so decks showed two pour lists. The links couldn't replace the text
# because they carried only a bottle reference and a label, while a written
# card carried name, region, price, style and notes, and could describe a pour
# that isn't a catalog bottle at all (a cocktail).
#
# This gives the table those fields and makes bottle_id optional, so one row
# can be either a catalog-linked pour or a free-text one. The legacy column is
# NOT dropped here: the data migration reads it, and it stays as the backup
# until the migrated decks are verified in production.
class ExpandPresentationBottlesIntoThePourList < ActiveRecord::Migration[8.0]
  def up
    change_table :presentation_bottles, bulk: true do |t|
      t.string :name      # free-text pour name, when there's no catalog bottle
      t.string :price     # per-deck advice that ages, not a property of a bottle
      # text, not string: real decks use these for full paragraphs. "Style" on
      # a live deck runs past 200 chars describing distillation and maturation.
      t.text   :origin    # legacy "region"; the Bottle supplies this when linked
      t.text   :style     # ditto
      t.text   :notes     # deck-specific, e.g. "pour it for the 1820s chapter"
    end

    change_column_null :presentation_bottles, :bottle_id, true

    # Postgres treats NULLs as distinct, so the existing unique index on
    # (presentation_id, bottle_id) still blocks linking the same bottle twice
    # while allowing any number of free-text rows.
  end

  def down
    # Free-text rows cannot survive a bottle_id NOT NULL constraint.
    PresentationBottle.where(bottle_id: nil).delete_all
    change_column_null :presentation_bottles, :bottle_id, false
    change_table :presentation_bottles, bulk: true do |t|
      t.remove :name, :origin, :style, :price, :notes
    end
  end
end
