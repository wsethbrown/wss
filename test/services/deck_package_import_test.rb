require "test_helper"
require_relative "../support/deck_package_fixture"

# A deck package is a folder holding everything a finished deck needs:
# deck.json, speaker-notes.md, the deck file, the two PDFs and the rendered
# slides. DeckPackageImport turns one into a Presentation with its downloads,
# cover, pour list and tags, and can be run again without duplicating anything.
class DeckPackageImportTest < ActiveSupport::TestCase
  include DeckPackageFixture

  setup do
    @dir = build_deck_package(Dir.mktmpdir("deck-package"))
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

  # --- An explicit target: replace a live deck in place, whatever its title ---

  def live_deck(title: "The Old Title")
    deck = Presentation.create!(author: users(:john), title: title, content: "Old story.", price: 24,
                                description: "Old description.", category: "Bourbon", featured: true)
    deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 old deck"), filename: "old-deck.pdf", content_type: "application/pdf")
    deck.slide_images.attach(io: File.open(Rails.root.join("test/fixtures/files/slides/slide-09.png"), "rb"),
                             filename: "old-slide.png", content_type: "image/png")
    deck.update!(published: true)
    deck.update_columns(download_count: 7)
    deck
  end

  test "into: updates that deck in place, whatever its title, and keeps what the admin owns" do
    deck = live_deck
    buyer = users(:jane)
    UserPresentation.create!(user: buyer, presentation: deck, purchase_type: "direct", purchased_at: Time.current)

    assert_no_difference [ -> { Presentation.count }, -> { UserPresentation.count } ] do
      updated = DeckPackageImport.call(@dir, author: users(:admin), into: deck)
      assert_equal deck.id, updated.id
    end

    deck.reload
    assert_equal "Test Deck", deck.title, "the package's title replaces the old one"
    assert_equal "A deck for the tests. Two pours.", deck.description
    assert_equal "Rye", deck.category
    assert_match(/\A## Test Deck/, deck.content.strip)
    assert_equal 3, deck.slide_images.count
    assert_equal %w[slide-01.png slide-02.png slide-03.png], deck.slide_images.order(:id).map { |s| s.filename.to_s }
    assert_equal "Test-Deck.pptx", deck.pdf_file.filename.to_s
    assert_equal [ "A Rye", "A Bourbon" ], deck.pour_list.map(&:title)

    assert_equal BigDecimal("24"), deck.price, "price is the admin's, not the package's"
    assert deck.published?, "a live deck stays live"
    assert deck.featured?, "the featured flag is the admin's"
    assert_equal users(:john), deck.author
    assert_equal 7, deck.download_count
    assert deck.purchased_by?(buyer)
  end

  test "into: refuses a title another deck already has and changes nothing" do
    deck = live_deck
    Presentation.create!(author: users(:admin), title: "Test Deck", content: "Someone else.", price: 3)

    other = Presentation.find_by(title: "Test Deck")
    error = assert_raises(DeckPackageImport::TitleTaken) { DeckPackageImport.call(@dir, author: users(:admin), into: deck) }
    assert_match(/already called "Test Deck"/, error.message)
    assert_equal other, error.deck
    assert_equal "The Old Title", deck.reload.title
  end

  test "into: a package refused part-way leaves the deck exactly as it was" do
    deck = live_deck
    old_slide_ids = deck.slide_images.order(:id).pluck(:blob_id)
    write_meta(description: "x" * 1001) # fails the model's length validation on save

    assert_raises(DeckPackageImport::Invalid) { DeckPackageImport.call(@dir, author: users(:admin), into: deck) }

    deck.reload
    assert_equal "The Old Title", deck.title
    assert_equal "Old description.", deck.description
    assert_equal "old-deck.pdf", deck.pdf_file.filename.to_s
    assert_equal old_slide_ids, deck.slide_images.order(:id).pluck(:blob_id)
    assert ActiveStorage::Blob.where(id: old_slide_ids).exists?, "the old slides were not purged"
    assert_empty deck.presentation_bottles
  end

  test "into: a package missing a required file is refused before anything changes" do
    deck = live_deck
    FileUtils.rm_rf(File.join(@dir, "slides"))
    error = assert_raises(DeckPackageImport::Invalid) { DeckPackageImport.call(@dir, author: users(:admin), into: deck) }
    assert_match(%r{slides/slide-01\.png}, error.message)
    assert_equal "The Old Title", deck.reload.title
  end

  test "into: says when the package leaves an old download in place" do
    deck = live_deck
    deck.outline_file.attach(io: StringIO.new("%PDF-1.4 old outline"), filename: "old-outline.pdf", content_type: "application/pdf")
    FileUtils.rm(File.join(@dir, "Test-Deck-research-outline.pdf"))

    importer = DeckPackageImport.new(@dir, author: users(:admin), into: deck)
    importer.call
    assert_equal "old-outline.pdf", deck.reload.outline_file.filename.to_s
    assert importer.warnings.any? { |w| w.include?("research outline") && w.include?("old-outline.pdf") }, importer.warnings.inspect
  end

  # --- create_only: the admin's "Upload a package" never overwrites by title ---

  test "create_only: refuses a title that is taken, pointing at that deck" do
    existing = Presentation.create!(author: users(:admin), title: "Test Deck", content: "Live.", price: 9)

    error = assert_raises(DeckPackageImport::TitleTaken) do
      DeckPackageImport.call(@dir, author: users(:admin), create_only: true)
    end
    assert_equal existing, error.deck
    assert_match(/Replace with a package/, error.message)
    assert_equal "Live.", existing.reload.content
  end

  test "create_only: creates a draft when the title is free" do
    deck = DeckPackageImport.call(@dir, author: users(:admin), create_only: true)
    assert deck.persisted?
    assert_not deck.published?
  end

  test "warns, without refusing, when the slide count and the script's sections differ" do
    File.write(File.join(@dir, "speaker-notes.md"), "---\n\n## [SLIDE 1] One\n\nHi.\n\n## [SLIDE 2] Two\n\nBye.\n")
    importer = DeckPackageImport.new(@dir, author: users(:admin))
    deck = importer.call
    assert deck.persisted?
    assert importer.warnings.any? { |w| w.include?("3 slides") && w.include?("2 [SLIDE n] sections") }, importer.warnings.inspect
  end

  test "warns about nothing for a complete, matching package" do
    importer = DeckPackageImport.new(@dir, author: users(:admin))
    importer.call
    assert_empty importer.warnings
  end

  # --- The script for each slide, kept for the admin deck page ---

  test "keeps the script for each slide, in order, without changing the story" do
    deck = DeckPackageImport.call(@dir, author: users(:admin))

    assert_equal [
      { "title" => "Test Deck", "body" => "Thanks for coming." },
      { "title" => "Pour one — A Rye", "body" => "Try it neat." },
      { "title" => "Last word", "body" => "Goodnight." }
    ], deck.reload.slide_script
    assert_match(/\A## Test Deck/, deck.content.strip, "the story is built as before")
    assert_no_match(/Running order/, deck.slide_script.to_json, "the presenter's set-up block is not a slide")
  end

  test "a section's body keeps its Markdown and drops a trailing rule" do
    File.write(File.join(@dir, "speaker-notes.md"), <<~MD)
      Set-up.

      ---

      ## [SLIDE 1] Open

      _Hold up the glass._

      > **SAY IT**
      > Out loud.

      ---

      ## [SLIDE 2] Close

      Bye.
    MD
    deck = DeckPackageImport.call(@dir, author: users(:admin))
    first = deck.reload.slide_script.first
    assert_equal "Open", first["title"]
    assert_equal "_Hold up the glass._\n\n> **SAY IT**\n> Out loud.", first["body"]
  end

  test "a re-import replaces the script, and a script with no slide sections leaves it empty" do
    deck = DeckPackageImport.call(@dir, author: users(:admin))
    File.write(File.join(@dir, "speaker-notes.md"), "## [SLIDE 1] Only one\n\nNew words.\n")
    DeckPackageImport.call(@dir, author: users(:admin), into: deck)
    assert_equal [ { "title" => "Only one", "body" => "New words." } ], deck.reload.slide_script

    File.write(File.join(@dir, "speaker-notes.md"), "## A chapter\n\nNo slide markers here.\n")
    DeckPackageImport.call(@dir, author: users(:admin), into: deck)
    assert_equal [], deck.reload.slide_script
  end

  test "a package refused on save leaves the old script in place" do
    deck = DeckPackageImport.call(@dir, author: users(:admin))
    old = deck.reload.slide_script
    File.write(File.join(@dir, "speaker-notes.md"), "## [SLIDE 1] Replaced\n\nGone.\n")
    write_meta(description: "x" * 1001)
    assert_raises(DeckPackageImport::Invalid) { DeckPackageImport.call(@dir, author: users(:admin), into: deck) }
    assert_equal old, deck.reload.slide_script
  end

  test "publish: a $0 package is not published free unless that is confirmed" do
    write_meta(price: 0)
    assert_raises(DeckPackageImport::Invalid) { DeckPackageImport.call(@dir, author: users(:admin), publish: true) }
    assert_nil Presentation.find_by(title: "Test Deck")
    assert DeckPackageImport.call(@dir, author: users(:admin), publish: true, free_confirmed: true).published?
  end

  private

  def write_meta(overrides = {}) = write_deck_meta(@dir, overrides)
end
