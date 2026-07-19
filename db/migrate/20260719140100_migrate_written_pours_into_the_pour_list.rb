# Move every written pour card onto `presentation_bottles`, matching a catalog
# bottle by name where one exists so the deck gains the review ties, and
# falling back to a free-text row where it doesn't (cocktails, bottles not in
# the catalog).
#
# Idempotent: a deck that already has rows is skipped, so a re-run can't
# duplicate a pour list. The legacy column is left in place as the backup.
class MigrateWrittenPoursIntoThePourList < ActiveRecord::Migration[8.0]
  def up
    migrated = skipped = linked = freetext = 0

    Presentation.find_each do |deck|
      written = deck.parsed_whiskey_recommendations
      next if written.empty?

      if deck.presentation_bottles.exists?
        skipped += 1
        say "deck #{deck.id} (#{deck.title}) already has a pour list, leaving it alone"
        next
      end

      written.each_with_index do |card, i|
        name = card[:name].to_s.strip
        next if name.blank?

        bottle = match_bottle(name)
        bottle ? linked += 1 : freetext += 1

        deck.presentation_bottles.create!(
          bottle: bottle,
          position: i + 1,
          # Keep the written text even when linked: it's the deck author's
          # recommendation, not a property of the bottle.
          name: bottle ? nil : name,
          origin: card[:region].presence,
          style: card[:style].presence,
          price: card[:price].presence,
          notes: card[:notes].presence
        )
      end

      migrated += 1
      say "deck #{deck.id} (#{deck.title}): #{written.size} pour(s) migrated"
    end

    say "Pour lists migrated: #{migrated} deck(s), #{linked} linked to catalog bottles, " \
        "#{freetext} kept as free text, #{skipped} deck(s) skipped."
  end

  def down
    say "Written pours are still in presentations.whiskey_recommendations; nothing to undo."
  end

  private

  # Exact name match only, case-insensitive. A fuzzy match that silently binds
  # a deck's pour to the wrong bottle would put the wrong reviews on the page,
  # which is worse than leaving it as text for an admin to link by hand.
  def match_bottle(name)
    Bottle.where("LOWER(name) = ?", name.downcase).first
  end
end
