require "test_helper"

# A deck package is a folder holding everything a finished deck needs:
# deck.json, speaker-notes.md, the deck file, the two PDFs and the rendered
# slides. DeckPackageImport turns one into a Presentation with its downloads,
# cover, pour list and tags, and can be run again without duplicating anything.
class DeckPackageImportTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir("deck-package")
    FileUtils.mkdir_p(File.join(@dir, "slides"))
    slides = Rails.root.join("test/fixtures/files/slides")
    %w[slide-01.png slide-02.png slide-03.png].each { |f| FileUtils.cp(slides.join(f), File.join(@dir, "slides", f)) }
    FileUtils.cp(Rails.root.join("test/fixtures/files/tiny_deck.pptx"), File.join(@dir, "Test-Deck.pptx"))
    File.binwrite(File.join(@dir, "Test-Deck-speaker-notes.pdf"), "%PDF-1.4 notes")
    File.binwrite(File.join(@dir, "Test-Deck-research-outline.pdf"), "%PDF-1.4 outline")
    File.write(File.join(@dir, "speaker-notes.md"), <<~MD)
      # Test Deck — Speaker Notes

      Running order and set-up, for the presenter only.

      ---

      ## [SLIDE 1] Test Deck

      Thanks for coming.

      ## [SLIDE 2] Pour one — A Rye

      Try it neat.
    MD
    write_meta
  end

  teardown { FileUtils.remove_entry(@dir) }

  test "creates an unpublished deck with its story, files, cover, pours and tags" do
    deck = DeckPackageImport.call(@dir, author: users(:admin))

    assert deck.persisted?
    assert_not deck.published?, "import drafts, never auto-publish"
    assert_equal "Test Deck", deck.title
    assert_equal "Rye", deck.category
    assert_equal "Beginner", deck.difficulty
    assert_equal "45 min", deck.duration
    assert_equal BigDecimal("19.99"), deck.price
    assert_match(/\A## Test Deck/, deck.content.strip)
    assert_no_match(/\[SLIDE/, deck.content)
    assert_no_match(/Running order/, deck.content, "the presenter's set-up notes are not part of the story")

    assert_equal "Test-Deck.pptx", deck.pdf_file.filename.to_s
    assert deck.speaker_notes.attached?
    assert deck.outline_file.attached?
    assert deck.featured_image.attached?
    assert_equal 3, deck.slide_images.count

    pours = deck.pour_list.to_a
    assert_equal [ "A Rye", "A Bourbon" ], pours.map(&:title)
    assert_equal "Somewhere, Kentucky", pours.first.origin
    assert_equal "Straight rye", pours.first.style
    assert_equal "Pour 1 · 100 proof", pours.first.label
    assert_equal %w[history rye], deck.tags.map(&:name).sort
  end

  test "publishes when asked and the deck is ready" do
    deck = DeckPackageImport.call(@dir, author: users(:admin), publish: true)
    assert deck.published?
  end

  test "running it twice updates the same deck and duplicates nothing" do
    first = DeckPackageImport.call(@dir, author: users(:admin), publish: true)
    write_meta(description: "A new description. Two pours.")

    assert_no_difference -> { Presentation.count } do
      second = DeckPackageImport.call(@dir, author: users(:admin))
      assert_equal first.id, second.id
      assert_equal "A new description. Two pours.", second.description
      assert second.published?, "a re-import does not unpublish a live deck"
      assert_equal 3, second.slide_images.count
      assert_equal 2, second.presentation_bottles.count
    end
  end

  test "a re-import keeps the price an admin has set" do
    deck = DeckPackageImport.call(@dir, author: users(:admin))
    deck.update_columns(price: 5)
    assert_equal BigDecimal("5"), DeckPackageImport.call(@dir, author: users(:admin)).price
  end

  test "refuses a package with no deck file" do
    FileUtils.rm(File.join(@dir, "Test-Deck.pptx"))
    error = assert_raises(DeckPackageImport::Invalid) { DeckPackageImport.call(@dir, author: users(:admin)) }
    assert_match(/Test-Deck\.pptx/, error.message)
    assert_nil Presentation.find_by(title: "Test Deck")
  end

  private

  def write_meta(overrides = {})
    meta = {
      slug: "Test-Deck", title: "Test Deck", subtitle: "A test", category: "Rye",
      difficulty: "Beginner", duration: "45 min", price: 19.99,
      description: "A deck for the tests. Two pours.", tags: "rye, history",
      pours: [
        { name: "A Rye", origin: "Somewhere, Kentucky", style: "Straight rye", strength: "100 proof", notes: "Try it neat." },
        { name: "A Bourbon", origin: "Elsewhere, Kentucky", style: "Straight bourbon" }
      ]
    }.merge(overrides)
    File.write(File.join(@dir, "deck.json"), JSON.generate(meta))
  end
end
