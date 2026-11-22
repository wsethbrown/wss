require "test_helper"

# The deck page renders the deck's extra sections, in order, where "What
# you'll taste" used to be, by one rule (PresentationsHelper#deck_section_layout):
# a section whose only line is plain is a paragraph; otherwise its lines are
# rows, and "Label: text" is a labelled row. Plain text, always escaped.
class DeckExtraSectionsTest < ActionDispatch::IntegrationTest
  def deck_with(sections, **attrs)
    deck = Presentation.create!(author: users(:admin), title: "Sections Deck", content: "A story.", price: 10,
                                sections: sections, **attrs)
    deck.update_column(:published, true) # skip the deck-file publish guard
    deck
  end

  test "each section renders under its heading, in order, after the story" do
    deck = deck_with([ { "heading" => "What you'll need", "lines" => [ "Crushed ice", "Fresh mint" ] },
                       { "heading" => "Who it's for", "lines" => [ "A first tasting night." ] } ])
    get presentation_path(deck)
    assert_response :success

    assert_equal [ "What you'll need", "Who it's for" ], css_select("[data-deck-section] h2").map { |h| h.text.squish }
    body = response.body
    assert_operator body.index("deck-story"), :<, body.index("What you&#39;ll need")
  end

  test "a section whose only line is plain text is a short paragraph" do
    get presentation_path(deck_with([ { "heading" => "Who it's for", "lines" => [ "A first tasting night." ] } ]))
    assert_select "[data-deck-section] p.font-reading", text: "A first tasting night."
    assert_select "[data-deck-section] li", 0
  end

  test "several lines are a list of rows, and Label: text is a labelled row" do
    get presentation_path(deck_with([ { "heading" => "What you'll taste",
                                        "lines" => [ "Nose: vanilla and oak", "Palate: caramel", "A plain row" ] } ]))
    rows = css_select("[data-deck-section] li")
    assert_equal 3, rows.size
    assert_equal "Nose", rows[0].css("span.text-mute").text
    assert_equal "vanilla and oak", rows[0].css("span.font-reading").text
    assert_equal "Palate", rows[1].css("span.text-mute").text
    assert_empty rows[2].css("span.text-mute"), "a plain line has no label"
    assert_equal "A plain row", rows[2].text.squish
  end

  test "a single labelled line is a row, not a paragraph" do
    get presentation_path(deck_with([ { "heading" => "Body", "lines" => [ "Mouthfeel: oily" ] } ]))
    assert_select "[data-deck-section] li span.text-mute", text: "Mouthfeel"
    assert_select "[data-deck-section] p.font-reading", 0
  end

  test "a label is at most 24 characters, and needs a space after the colon" do
    long = "#{'L' * 25}: text"
    get presentation_path(deck_with([ { "heading" => "Rows", "lines" => [ long, "Time:10pm", "Glass A: first" ] } ]))
    rows = css_select("[data-deck-section] li")
    assert_empty rows[0].css("span.text-mute")
    assert_equal long, rows[0].text.squish
    assert_empty rows[1].css("span.text-mute")
    assert_equal "Glass A", rows[2].css("span.text-mute").text
  end

  test "headings and lines are plain text: HTML is escaped and Markdown is not rendered" do
    get presentation_path(deck_with([ { "heading" => "<script>alert(1)</script> **Bold**",
                                        "lines" => [ "<b>Nose</b>: <img src=x onerror=alert(2)>", "*not italic*" ] } ]))
    assert_no_match "<script>alert(1)</script>", response.body
    assert_no_match "<img src=x", response.body
    assert_select "[data-deck-section] h2", text: "<script>alert(1)</script> **Bold**"
    assert_select "[data-deck-section] script", 0
    assert_select "[data-deck-section] em", 0
    assert_select "[data-deck-section] li span.text-mute", text: "<b>Nose</b>"
  end

  test "nothing renders for a deck with no sections" do
    get presentation_path(deck_with([]))
    assert_response :success
    assert_select "[data-deck-section]", 0
  end

  test "the old tasting boxes are gone from the page" do
    deck = deck_with([], nose_notes: "Hidden pear", palate_notes: "Hidden oak")
    get presentation_path(deck)
    assert_no_match "Hidden pear", response.body
    assert_no_match "Hidden oak", response.body
    assert_select "h2", text: "What you'll taste", count: 0
  end
end
