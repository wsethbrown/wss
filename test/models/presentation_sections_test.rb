require "test_helper"

# The deck page's extra sections (Presentation#sections) and the one writer of
# the takeaways format (Presentation#takeaways=).
class PresentationSectionsTest < ActiveSupport::TestCase
  def deck(**attrs)
    Presentation.new(author: users(:admin), title: "Sections Deck", content: "A story.", price: 5, **attrs)
  end

  # --- Normalising on assignment ---

  test "a new deck has no sections" do
    assert_equal [], deck.sections
  end

  test "headings and lines are stripped, blank lines dropped, empty sections dropped" do
    d = deck(sections: [
      { "heading" => "  What you'll need ", "lines" => [ " Crushed ice ", "", "   ", "Fresh mint" ] },
      { "heading" => "", "lines" => [ "", " " ] },
      { heading: "Who it's for", lines: [ "New to rye." ] }
    ])
    assert_equal [ { "heading" => "What you'll need", "lines" => [ "Crushed ice", "Fresh mint" ] },
                   { "heading" => "Who it's for", "lines" => [ "New to rye." ] } ], d.sections
  end

  test "lines typed in one textarea are split, one per line" do
    d = deck(sections: [ { "heading" => "On the night", "lines" => "Glass A: first\r\n\r\n Glass B: later \n" } ])
    assert_equal [ "Glass A: first", "Glass B: later" ], d.sections.first["lines"]
  end

  test "indexed form fields are taken in key order" do
    d = deck(sections: { "1" => { "heading" => "Second", "lines" => "b" }, "0" => { "heading" => "First", "lines" => "a" } })
    assert_equal %w[First Second], d.sections.map { |s| s["heading"] }
  end

  test "form parameters are accepted as they arrive" do
    params = ActionController::Parameters.new(sections: [ { heading: "H", lines: "x\ny" } ]).permit(sections: [ :heading, :lines ])
    assert_equal [ { "heading" => "H", "lines" => %w[x y] } ], deck(sections: params[:sections]).sections
  end

  test "a heading on several lines becomes one line" do
    assert_equal "Two words", deck(sections: [ { "heading" => "Two\nwords", "lines" => [ "x" ] } ]).sections.first["heading"]
  end

  # --- Limits, with plain-language errors ---

  test "a sensible deck is valid" do
    assert deck(sections: [ { "heading" => "H", "lines" => [ "Nose: oak" ] } ]).valid?
  end

  test "at most 8 sections" do
    d = deck(sections: Array.new(9) { |i| { "heading" => "S#{i}", "lines" => [ "x" ] } })
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Extra sections can have at most 8 sections (there are 9)"
  end

  test "a heading of up to 80 characters" do
    assert deck(sections: [ { "heading" => "h" * 80, "lines" => [ "x" ] } ]).valid?
    d = deck(sections: [ { "heading" => "h" * 81, "lines" => [ "x" ] } ])
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Extra sections allow headings of up to 80 characters (section 1 has 81)"
  end

  test "at most 12 lines in a section" do
    assert deck(sections: [ { "heading" => "H", "lines" => Array.new(12, "x") } ]).valid?
    d = deck(sections: [ { "heading" => "H", "lines" => Array.new(13, "x") } ])
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Extra sections allow up to 12 lines in a section (section 1 has 13)"
  end

  test "a line of up to 300 characters" do
    assert deck(sections: [ { "heading" => "H", "lines" => [ "l" * 300 ] } ]).valid?
    d = deck(sections: [ { "heading" => "H", "lines" => [ "ok", "l" * 301 ] } ])
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Extra sections allow lines of up to 300 characters (section 1, line 2 has 301)"
  end

  test "a section needs a heading and a line" do
    d = deck(sections: [ { "heading" => "", "lines" => [ "x" ] }, { "heading" => "Only a heading", "lines" => [] } ])
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Extra sections need a heading in section 1"
    assert_includes d.errors.full_messages, "Extra sections need at least one line in section 2"
  end

  test "sections_in_error names the sections at fault, or all of them for a whole-list problem" do
    ok = { "heading" => "Fine", "lines" => [ "x" ] }
    bad = { "heading" => "", "lines" => [ "x" ] }
    assert_equal [], Presentation.sections_in_error([ ok, ok ])
    assert_equal [ 2 ], Presentation.sections_in_error([ ok, bad, ok ])
    assert_equal (1..9).to_a, Presentation.sections_in_error(Array.new(9, ok))
  end

  test "something that is not a list of sections is refused, not stored" do
    d = deck(sections: "Nose: oak")
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Extra sections must be a list of sections"
    d = deck(sections: [ "Nose: oak" ])
    assert_not d.valid?
    assert_includes d.errors.full_messages, "Extra sections need a heading and a list of lines in section 1"
  end

  test "the limits apply when the sections change, so an old over-long line never blocks other edits" do
    d = deck
    d.save!
    d.update_columns(sections: [ { "heading" => "Old", "lines" => [ "l" * 400 ] } ])
    d.reload
    assert d.update(title: "Renamed Deck"), d.errors.full_messages.inspect
    assert d.update(sections: [ { "heading" => "Old", "lines" => [ "l" * 400 ] } ]), "the same sections are not a change"
    assert_not d.update(sections: [ { "heading" => "New", "lines" => [ "l" * 400 ] } ])
  end

  # --- The takeaways writer and the reader agree ---

  test "takeaways= writes the format parsed_what_youll_learn reads, and it round-trips" do
    list = [ { "title" => "The Virginia paper trail", "text" => "Every early julep is a Virginia julep." },
             { "title" => "Bonded", "text" => "" },
             { "title" => "How a brandy drink became a bourbon one", "text" => "A tax revolt, a war and a French aphid." } ]
    d = deck(takeaways: list)
    assert_equal "- The Virginia paper trail\nEvery early julep is a Virginia julep.\n\n- Bonded\n\n\n" \
                 "- How a brandy drink became a bourbon one\nA tax revolt, a war and a French aphid.", d.what_youll_learn
    assert_equal list, d.takeaways
    assert_equal [ "The Virginia paper trail", "Bonded", "How a brandy drink became a bourbon one" ],
                 d.parsed_what_youll_learn.map { |point| point[:title] }
  end

  test "takeaways= squishes each entry onto one line, so text on several lines reads back whole" do
    d = deck(takeaways: [ { title: " Two\nlines ", text: "First part.\n\nSecond part." } ])
    assert_equal [ { "title" => "Two lines", "text" => "First part. Second part." } ], d.takeaways
  end

  test "takeaways= drops an entry with no title, and an empty list clears the field" do
    assert_equal [ "Kept" ], deck(takeaways: [ { title: "", text: "Lost." }, { title: "Kept", text: "x" } ]).takeaways.map { |t| t["title"] }
    d = deck(what_youll_learn: "- Old\nx")
    d.takeaways = []
    assert_nil d.what_youll_learn
  end
end
