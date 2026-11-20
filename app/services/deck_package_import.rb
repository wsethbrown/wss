# Loads a finished deck from a "deck package" folder into the library.
#
# A package holds everything the deck page and its owner downloads need:
#
#   deck.json                      title, category, difficulty, duration, description,
#                                  price (optional), tags, pours
#   speaker-notes.md               the script; one "## [SLIDE n] Title" section per slide
#   <slug>.pptx                    the deck file buyers download
#   <slug>-speaker-notes.pdf       owner download
#   <slug>-research-outline.pdf    owner download
#   slides/slide-01.png ...        the rendered slides, in order; the first is the cover
#
# The slides arrive already rendered, so nothing here runs LibreOffice and no
# render job is enqueued. Run it again on the same package and it updates the
# same deck (matched by title): files and pours are replaced, while the price
# and the published state an admin has set are left alone.
#
# New decks are created unpublished unless `publish: true` is passed, in line
# with the import rule: import drafts, humans publish.
class DeckPackageImport
  class Invalid < StandardError; end

  DEFAULT_PRICE = BigDecimal("12.99")

  def self.call(dir, author:, publish: false)
    new(dir, author: author, publish: publish).call
  end

  def initialize(dir, author:, publish: false)
    @dir = Pathname(dir)
    @author = author
    @publish = publish
  end

  def call
    meta = read_meta
    check_files!(meta)
    deck = Presentation.find_or_initialize_by(title: meta.fetch("title"))
    created = deck.new_record?

    Presentation.transaction do
      deck.assign_attributes(
        author: deck.author || @author,
        description: meta["description"],
        category: meta["category"],
        difficulty: meta["difficulty"],
        duration: meta["duration"],
        content: story
      )
      deck.price = BigDecimal((meta["price"] || DEFAULT_PRICE).to_s) if created
      deck.published = false if created
      deck.save!

      attach_files(deck, meta)
      replace_pours(deck, meta["pours"])
      deck.tag_names = meta["tags"] if meta["tags"].present?
      deck.update!(published: true) if @publish && !deck.published?
    end

    Rails.logger.info(
      "[DeckPackageImport] #{created ? 'created' : 'updated'} presentation #{deck.id} (#{deck.title}): " \
      "#{deck.slide_images.count} slides, #{deck.presentation_bottles.count} pours, published=#{deck.published?}"
    )
    deck
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[DeckPackageImport] #{@dir.basename}: #{e.class}: #{e.message}")
    raise Invalid, "#{@dir.basename}: #{e.message}"
  end

  private

  def read_meta
    file = @dir.join("deck.json")
    raise Invalid, "#{@dir.basename}: deck.json is missing" unless file.file?

    meta = JSON.parse(file.read)
    %w[slug title].each { |key| raise Invalid, "#{@dir.basename}: deck.json has no #{key}" if meta[key].blank? }
    meta
  rescue JSON::ParserError => e
    Rails.logger.error("[DeckPackageImport] #{@dir.basename}: deck.json is not valid JSON: #{e.message}")
    raise Invalid, "#{@dir.basename}: deck.json is not valid JSON"
  end

  def check_files!(meta)
    slug = meta["slug"]
    missing = [ "#{slug}.pptx", "speaker-notes.md" ].reject { |name| @dir.join(name).file? }
    missing << "slides/slide-01.png" if slide_paths.empty?
    return if missing.empty?

    Rails.logger.warn("[DeckPackageImport] #{@dir.basename}: refused, missing #{missing.join(', ')}")
    raise Invalid, "#{@dir.basename}: missing #{missing.join(', ')}"
  end

  # The script, as the story readers see: the presenter's set-up block above
  # the first rule is dropped, and "## [SLIDE 4] Title" becomes "## Title".
  def story
    text = @dir.join("speaker-notes.md").read
    text = text.split(/^---\s*$/, 2).last if text.match?(/^---\s*$/)
    text.gsub(/^## \[SLIDE \d+\] /, "## ").strip
  end

  def slide_paths
    @slide_paths ||= @dir.glob("slides/slide-*.png").sort
  end

  def attach_files(deck, meta)
    slug = meta["slug"]
    attach_one(deck.pdf_file, @dir.join("#{slug}.pptx"))
    attach_one(deck.speaker_notes, @dir.join("#{slug}-speaker-notes.pdf"), "application/pdf")
    attach_one(deck.outline_file, @dir.join("#{slug}-research-outline.pdf"), "application/pdf")
    attach_one(deck.featured_image, slide_paths.first, "image/png")

    deck.slide_images.purge if deck.slide_images.attached?
    slide_paths.each do |path|
      deck.slide_images.attach(io: path.open("rb"), filename: path.basename.to_s, content_type: "image/png")
    end
  end

  def attach_one(attachment, path, content_type = nil)
    unless path&.file?
      Rails.logger.info("[DeckPackageImport] #{@dir.basename}: no #{path&.basename}, skipping that download")
      return
    end

    attachment.purge if attachment.attached?
    attachment.attach(io: path.open("rb"), filename: path.basename.to_s, content_type: content_type)
  end

  # The package is the source of truth for what the deck calls for, so the
  # pour list is rebuilt from it. Rows are free text: linking a pour to a
  # catalog bottle is an editorial step an admin does afterwards.
  def replace_pours(deck, pours)
    return if pours.blank?

    deck.presentation_bottles.destroy_all
    pours.each_with_index do |pour, index|
      pour = { "name" => pour } if pour.is_a?(String)
      deck.presentation_bottles.create!(
        position: index + 1,
        name: pour["name"],
        origin: pour["origin"].presence,
        style: pour["style"].presence,
        notes: pour["notes"].presence,
        label: [ "Pour #{index + 1}", pour["strength"].presence ].compact.join(" · ")
      )
    end
  end
end
