require "test_helper"
require Rails.root.join("db/migrate/20261122120100_carry_tasting_notes_into_sections")

# The four fixed tasting boxes became an extra section headed "What you'll
# taste": the migration carries each deck's notes into one, once.
class CarryTastingNotesIntoSectionsTest < ActiveSupport::TestCase
  def migrate(direction)
    migration = CarryTastingNotesIntoSections.new
    migration.verbose = false
    migration.migrate(direction)
    Presentation.reset_column_information
  end

  def deck(title, **attrs)
    Presentation.create!(author: users(:admin), title: title, content: "A story.", price: 5, **attrs)
  end

  test "carries the notes a deck has into one labelled section, and leaves other decks alone" do
    tasted = deck("Tasted Deck", nose_notes: "Plum, cherry", palate_notes: "Soft.\nRaisin and oak.", body_notes: "  ")
    plain = deck("Plain Deck")
    updated_at = tasted.updated_at

    migrate(:up)

    assert_equal [ { "heading" => "What you'll taste", "lines" => [ "Nose: Plum, cherry", "Palate: Soft. Raisin and oak." ] } ],
                 tasted.reload.sections
    assert_equal [], plain.reload.sections
    assert_equal updated_at.to_i, tasted.updated_at.to_i, "written with update_columns"
    assert_equal "Plum, cherry", tasted.nose_notes, "the old columns are kept"
  end

  test "adds after sections a deck already has" do
    d = deck("Mixed Deck", finish_notes: "Long")
    d.update_columns(sections: [ { "heading" => "On the night", "lines" => [ "Glass A first" ] } ])
    migrate(:up)
    assert_equal [ "On the night", "What you'll taste" ], d.reload.sections.map { |s| s["heading"] }
  end

  test "running it twice adds nothing the second time" do
    d = deck("Twice Deck", nose_notes: "Pear")
    migrate(:up)
    migrate(:up)
    assert_equal 1, d.reload.sections.size
  end

  test "a deck that already has a What you'll taste section is left as it is" do
    d = deck("Typed Deck", nose_notes: "Pear")
    d.update_columns(sections: [ { "heading" => "What you'll taste", "lines" => [ "Nose: pear and honey" ] } ])
    migrate(:up)
    assert_equal [ "Nose: pear and honey" ], d.reload.sections.sole["lines"]
  end

  test "a deck whose notes are only line breaks and tabs gets no section" do
    d = deck("Blank Deck", nose_notes: "\r\n", palate_notes: "\t", finish_notes: " \n ")
    migrate(:up)
    assert_equal [], d.reload.sections
  end

  test "a note longer than a section line is carried whole, and the deck still saves other edits" do
    long = "Oak. " * 70 # 350 characters
    d = deck("Long Note Deck", nose_notes: long)
    migrate(:up)
    line = d.reload.sections.sole["lines"].sole
    assert_equal "Nose: #{long.squish}", line
    assert_operator line.length, :>, Presentation::SECTION_LINE_MAX

    assert d.update(title: "Long Note Deck Renamed"), d.errors.full_messages.inspect
    assert_equal line, d.reload.sections.sole["lines"].sole
  end

  test "a deck that already has the most sections allowed still gets its notes, one over the limit" do
    d = deck("Full Deck", body_notes: "Light")
    full = Array.new(Presentation::SECTIONS_MAX) { |i| { "heading" => "Section #{i + 1}", "lines" => [ "x" ] } }
    d.update_columns(sections: full)
    migrate(:up)

    d.reload
    assert_equal Presentation::SECTIONS_MAX + 1, d.sections.size
    assert_equal({ "heading" => "What you'll taste", "lines" => [ "Body: Light" ] }, d.sections.last)
    assert d.update(title: "Full Deck Renamed"), "an unrelated edit still saves"
    assert_not d.update(sections: d.sections + [ { "heading" => "One more", "lines" => [ "y" ] } ]),
               "changing its sections means bringing them within the limit"
  end

  test "down removes only the section it wrote, while it still matches the notes" do
    carried = deck("Carried Deck", nose_notes: "Pear")
    edited = deck("Edited Deck", nose_notes: "Oak")
    migrate(:up)
    edited.update_columns(sections: [ { "heading" => "What you'll taste", "lines" => [ "Nose: oak, edited" ] } ])

    migrate(:down)
    assert_equal [], carried.reload.sections
    assert_equal [ "Nose: oak, edited" ], edited.reload.sections.sole["lines"]
  end
end
