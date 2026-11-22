# The four fixed tasting boxes (nose, palate, finish and body notes) are
# replaced by the deck's extra sections. Every deck with any of those notes
# gets one section headed "What you'll taste", one labelled line per note it
# has ("Nose: ..."), so the deck page keeps showing them.
#
# Nothing is shortened or dropped: a note longer than a section line may be
# (Presentation::SECTION_LINE_MAX, 300) is carried whole, and a deck that already
# has the most sections allowed still gets this one. The limits are checked
# only when an admin changes the sections, so such a deck still saves any
# other edit; changing its sections means bringing them within the limits.
#
# Safe to run twice: a deck that already has a "What you'll taste" section is
# left alone. The four old columns are not touched (they stay in the table,
# unread), so `down` only removes the section this migration wrote, and only
# while it still matches the notes exactly; a section the admin has edited
# since is kept.
#
# Writes through a bare table class with update_columns: no model callbacks,
# validations or timestamps.
class CarryTastingNotesIntoSections < ActiveRecord::Migration[8.1]
  HEADING = "What you'll taste".freeze
  NOTES = { "Nose" => "nose_notes", "Palate" => "palate_notes",
            "Finish" => "finish_notes", "Body" => "body_notes" }.freeze
  SECTIONS_MAX = 8 # Presentation::SECTIONS_MAX when this was written; only for the log line

  class Deck < ActiveRecord::Base
    self.table_name = "presentations"
  end

  def up
    Deck.reset_column_information
    carried = 0
    decks_with_notes.find_each do |deck|
      sections = Array(deck.sections)
      if sections.any? { |section| tasting_section?(section) }
        say "presentation #{deck.id}: already has a \"#{HEADING}\" section, left as it is"
        next
      end

      section = section_for(deck)
      # A note of only line breaks or tabs passes the query (TRIM strips
      # spaces) but squishes to nothing: no lines, no section.
      if section["lines"].empty?
        say "presentation #{deck.id}: its tasting notes are blank, nothing to carry"
        next
      end

      deck.update_columns(sections: sections + [ section ])
      carried += 1
      say "presentation #{deck.id}: tasting notes carried into a \"#{HEADING}\" section"
      if sections.size >= SECTIONS_MAX
        say "presentation #{deck.id}: now has #{sections.size + 1} sections, over the limit of " \
            "#{SECTIONS_MAX}; its sections can't be edited until one is removed"
      end
    end
    say "#{carried} deck(s) had their tasting notes carried into a section"
  end

  def down
    Deck.reset_column_information
    decks_with_notes.find_each do |deck|
      sections = Array(deck.sections)
      kept = sections.reject { |section| section == section_for(deck) }
      next if kept.size == sections.size

      deck.update_columns(sections: kept)
      say "presentation #{deck.id}: removed the carried \"#{HEADING}\" section"
    end
  end

  private

  def decks_with_notes
    Deck.where(NOTES.values.map { |column| "COALESCE(TRIM(#{column}), '') <> ''" }.join(" OR "))
  end

  def tasting_section?(section)
    section.is_a?(Hash) && section["heading"].to_s.strip.casecmp?(HEADING)
  end

  # Notes were typed in textareas, so each is squished onto one line.
  def section_for(deck)
    lines = NOTES.filter_map do |label, column|
      text = deck[column].to_s.squish
      "#{label}: #{text}" if text.present?
    end
    { "heading" => HEADING, "lines" => lines }
  end
end
