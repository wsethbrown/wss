# Builds a tiny but complete deck package from the test fixtures: deck.json,
# speaker-notes.md, the deck file, both PDFs and three rendered slides. Used by
# the DeckPackageImport, DeckPackageZip and admin upload tests.
module DeckPackageFixture
  SLIDES = %w[slide-01.png slide-02.png slide-03.png].freeze

  def build_deck_package(dir, meta: {}, script: nil)
    FileUtils.mkdir_p(File.join(dir, "slides"))
    slides = Rails.root.join("test/fixtures/files/slides")
    SLIDES.each { |f| FileUtils.cp(slides.join(f), File.join(dir, "slides", f)) }
    FileUtils.cp(Rails.root.join("test/fixtures/files/tiny_deck.pptx"), File.join(dir, "Test-Deck.pptx"))
    File.binwrite(File.join(dir, "Test-Deck-speaker-notes.pdf"), "%PDF-1.4 notes")
    File.binwrite(File.join(dir, "Test-Deck-research-outline.pdf"), "%PDF-1.4 outline")
    File.write(File.join(dir, "speaker-notes.md"), script || default_deck_script)
    write_deck_meta(dir, meta)
    dir
  end

  def default_deck_script
    <<~MD
      # Test Deck — Speaker Notes

      Running order and set-up, for the presenter only.

      ---

      ## [SLIDE 1] Test Deck

      Thanks for coming.

      ## [SLIDE 2] Pour one — A Rye

      Try it neat.

      ## [SLIDE 3] Last word

      Goodnight.
    MD
  end

  def write_deck_meta(dir, overrides = {})
    meta = {
      slug: "Test-Deck", title: "Test Deck", subtitle: "A test", category: "Rye",
      difficulty: "Beginner", duration: "45 min", price: 19.99,
      description: "A deck for the tests. Two pours.", tags: "rye, history",
      pours: [
        { name: "A Rye", origin: "Somewhere, Kentucky", style: "Straight rye", strength: "100 proof", notes: "Try it neat." },
        { name: "A Bourbon", origin: "Elsewhere, Kentucky", style: "Straight bourbon" }
      ]
    }.merge(overrides)
    File.write(File.join(dir, "deck.json"), JSON.generate(meta))
  end

  # Zips a package folder. With `folder:` the files sit inside one top-level
  # folder, as Finder's "Compress" makes them; without it they sit at the root.
  def zip_deck_package(dir, zip_path, folder: nil)
    Zip::File.open(zip_path, create: true) do |zip|
      Dir.glob("**/*", base: dir).sort.each do |relative|
        source = File.join(dir, relative)
        next if File.directory?(source)

        zip.add([ folder, relative ].compact.join("/"), source)
      end
    end
    zip_path
  end
end
