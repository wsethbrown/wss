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

  # --- Takeaways and extra sections from deck.json ---

  SECTIONS = [
    { "heading" => "What you'll need", "lines" => [ "Crushed ice", "Fresh mint" ] },
    { "heading" => "  Who it's for ", "lines" => [ " New to rye. ", "" ] }
  ].freeze

  test "fills the takeaways and the extra sections from deck.json" do
    write_meta(sections: SECTIONS)
    deck = DeckPackageImport.call(@dir, author: users(:admin)).reload

    assert_equal [ { "title" => "Where the rye came from", "text" => "One distillery, two brands." },
                   { "title" => "How to taste it", "text" => "Neat, then with a drop of water." } ], deck.takeaways
    assert_equal "- Where the rye came from\nOne distillery, two brands.\n\n- How to taste it\nNeat, then with a drop of water.",
                 deck.what_youll_learn, "stored in the format the takeaway editor writes"
    assert_equal [ { "heading" => "What you'll need", "lines" => [ "Crushed ice", "Fresh mint" ] },
                   { "heading" => "Who it's for", "lines" => [ "New to rye." ] } ], deck.sections
  end

  test "a re-upload replaces the takeaways and sections when deck.json has them" do
    deck = live_deck
    deck.update!(what_youll_learn: "- Typed by hand\nOld.", sections: [ { "heading" => "Typed", "lines" => [ "x" ] } ])
    write_meta(takeaways: [ { title: "From the package", text: "New." } ], sections: SECTIONS.first(1))

    DeckPackageImport.call(@dir, author: users(:admin), into: deck)
    deck.reload
    assert_equal [ "From the package" ], deck.takeaways.map { |t| t["title"] }
    assert_equal [ "What you'll need" ], deck.sections.map { |s| s["heading"] }
  end

  test "an empty list clears them" do
    deck = live_deck
    deck.update!(what_youll_learn: "- Typed by hand\nOld.", sections: [ { "heading" => "Typed", "lines" => [ "x" ] } ])
    write_meta(takeaways: [], sections: [])

    importer = DeckPackageImport.new(@dir, author: users(:admin), into: deck)
    importer.call
    deck.reload
    assert_nil deck.what_youll_learn
    assert_equal [], deck.sections
    assert importer.warnings.any? { |w| w.include?("lists no takeaways") }, importer.warnings.inspect
  end

  test "an older package without the keys keeps what the admin typed, and says so" do
    deck = live_deck
    deck.update!(what_youll_learn: "- Typed by hand\nOld.", sections: [ { "heading" => "Typed", "lines" => [ "x" ] } ])
    write_meta_without(:takeaways, :sections)

    importer = DeckPackageImport.new(@dir, author: users(:admin), into: deck)
    importer.call
    deck.reload
    assert_equal "- Typed by hand\nOld.", deck.what_youll_learn
    assert_equal [ { "heading" => "Typed", "lines" => [ "x" ] } ], deck.sections
    assert_includes importer.warnings, "deck.json has no takeaways, so the deck keeps the takeaways it had."
  end

  test "a new deck from a package without takeaways is warned about" do
    write_meta_without(:takeaways)
    importer = DeckPackageImport.new(@dir, author: users(:admin))
    deck = importer.call
    assert_nil deck.what_youll_learn
    assert_equal [], deck.sections
    assert_includes importer.warnings, "deck.json lists no takeaways, so the deck page has no \"What you'll learn\" section."
  end

  # --- The subtitle from deck.json ---

  test "the package's subtitle fills the deck's" do
    assert_equal "A test", DeckPackageImport.call(@dir, author: users(:admin)).reload.subtitle
  end

  test "a re-upload sets the subtitle when deck.json has it, and a blank one clears it" do
    deck = live_deck
    deck.update!(subtitle: "Typed by hand")
    write_meta(subtitle: "From the package")
    DeckPackageImport.call(@dir, author: users(:admin), into: deck)
    assert_equal "From the package", deck.reload.subtitle

    write_meta(subtitle: "  ")
    DeckPackageImport.call(@dir, author: users(:admin), into: deck)
    assert_nil deck.reload.subtitle
  end

  test "a package without a subtitle keeps the admin's" do
    deck = live_deck
    deck.update!(subtitle: "Typed by hand")
    write_meta_without(:subtitle)
    DeckPackageImport.call(@dir, author: users(:admin), into: deck)
    assert_equal "Typed by hand", deck.reload.subtitle
  end

  test "a subtitle that is not text, or too long, refuses the package before anything changes" do
    deck = live_deck
    deck.update!(subtitle: "Typed by hand")
    { 42 => /"subtitle" must be text/, [ "A" ] => /"subtitle" must be text/, nil => /"subtitle" must be text/,
      "s" * 141 => /"subtitle" can be at most 140 characters \(it has 141\)/ }.each do |value, message|
      write_meta(subtitle: value)
      error = assert_raises(DeckPackageImport::Invalid) { DeckPackageImport.call(@dir, author: users(:admin), into: deck) }
      assert_match message, error.message
      deck.reload
      assert_equal "Typed by hand", deck.subtitle
      assert_equal "The Old Title", deck.title
    end
  end

  MALFORMED = {
    "takeaways not a list" => [ { takeaways: "Learn things" }, /"takeaways" must be a list/ ],
    "a takeaway without a title" => [ { takeaways: [ { text: "No title." } ] }, /title and a text for takeaway 1/ ],
    "a blank takeaway title" => [ { takeaways: [ { title: "  ", text: "x" } ] }, /needs a title for takeaway 1/ ],
    "a takeaway text that would read as a title" => [ { takeaways: [ { title: "A", text: "- b" } ] }, /can't start with a dash/ ],
    "too many takeaways" => [ { takeaways: Array.new(11) { |i| { title: "T#{i}", text: "x" } } }, /at most 10 takeaways/ ],
    "a long takeaway title" => [ { takeaways: [ { title: "t" * 121, text: "x" } ] }, /titles of up to 120 characters/ ],
    "sections not a list" => [ { sections: { heading: "x" } }, /"sections" must be a list/ ],
    "lines not a list" => [ { sections: [ { heading: "H", lines: "one line" } ] }, /list of lines \(text\) for section 1/ ],
    "a line that is not text" => [ { sections: [ { heading: "H", lines: [ 1 ] } ] }, /for section 1/ ],
    "a section without a heading" => [ { sections: [ { heading: "", lines: [ "x" ] } ] }, /need a heading in section 1/ ],
    "too many sections" => [ { sections: Array.new(9) { |i| { heading: "S#{i}", lines: [ "x" ] } } }, /at most 8 sections/ ],
    "a long heading" => [ { sections: [ { heading: "h" * 81, lines: [ "x" ] } ] }, /headings of up to 80/ ],
    "too many lines" => [ { sections: [ { heading: "H", lines: Array.new(13, "x") } ] }, /up to 12 lines/ ],
    "a long line" => [ { sections: [ { heading: "H", lines: [ "l" * 301 ] } ] }, /lines of up to 300/ ]
  }.freeze

  MALFORMED.each do |name, (meta, message)|
    test "refuses #{name}, before anything changes" do
      deck = live_deck
      kept_sections = [ { "heading" => "Typed by hand", "lines" => [ "Kept: yes" ] } ]
      deck.update!(what_youll_learn: "- Kept\nOld.", sections: kept_sections)
      # A valid value for the other key, so a refusal can't hide behind it.
      write_meta({ takeaways: [ { title: "New", text: "x" } ], sections: [ { heading: "New", lines: [ "x" ] } ] }.merge(meta))
      error = assert_raises(DeckPackageImport::Invalid) { DeckPackageImport.call(@dir, author: users(:admin), into: deck) }
      assert_match message, error.message
      deck.reload
      assert_equal "The Old Title", deck.title
      assert_equal "- Kept\nOld.", deck.what_youll_learn
      assert_equal kept_sections, deck.sections
    end
  end

  private

  def write_meta(overrides = {}) = write_deck_meta(@dir, overrides)
  def write_meta_without(*keys) = write_deck_meta(@dir, {}, without: keys)
end
