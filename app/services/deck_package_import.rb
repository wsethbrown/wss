# Loads a finished deck from a "deck package" folder into the library.
#
# A package holds everything the deck page and its owner downloads need:
#
#   deck.json                      title, subtitle, category, difficulty, duration, description,
#                                  price (optional), tags, pours, and optionally
#                                  takeaways [{ "title", "text" }] and
#                                  sections [{ "heading", "lines": [..] }]
#   speaker-notes.md               the script; one "## [SLIDE n] Title" section per slide
#   <slug>.pptx                    the deck file buyers download
#   <slug>-speaker-notes.pdf       owner download
#   <slug>-research-outline.pdf    owner download
#   slides/slide-01.png ...        the rendered slides, in order; the first is the cover
#
# The slides arrive already rendered, so nothing here runs LibreOffice and no
# render job is enqueued.
#
# Which deck it loads into:
#   into: deck         updates THAT deck, whatever its title (the admin's
#                      "Replace with a package", and `decks:load DECK_ID=`).
#   create_only: true  always creates; refuses with TitleTaken when a deck
#                      already has the package's title (the admin's
#                      "Upload a package", so an upload never overwrites a
#                      different deck by accident).
#   neither            the rake task's default: updates the deck with the same
#                      title, or creates one.
#
# On an update the package replaces the title, description, category,
# difficulty, running time, story, slide script, files, slides, pours and tags, while the
# price, the published state, the featured flag, the author, purchases and
# counters stay as the admin left them.
#
# The subtitle, the takeaways ("What you'll learn") and the extra sections are replaced only
# when deck.json has the key: an empty list clears them, and a package without
# the key (an older one) keeps what the admin typed on the deck page.
#
# Everything is checked before anything changes, and the changes are saved in
# one transaction: a package refused part-way leaves the deck as it was. New
# files are attached by replacement, so the old ones are purged only after the
# commit (never before), and a live deck is never left without slides.
#
# New decks are created unpublished unless `publish: true` is passed, in line
# with the import rule: import drafts, humans publish.
class DeckPackageImport
  class Invalid < StandardError; end

  # The package's title belongs to a deck the caller did not ask to update.
  class TitleTaken < Invalid
    attr_reader :deck

    def initialize(message, deck)
      super(message)
      @deck = deck
    end
  end

  DEFAULT_PRICE = BigDecimal("12.99")

  attr_reader :warnings

  def self.call(dir, **options)
    new(dir, **options).call
  end

  def initialize(dir, author:, publish: false, into: nil, create_only: false, free_confirmed: false)
    @dir = Pathname(dir)
    @author = author
    @publish = publish
    @into = into
    @create_only = create_only
    @free_confirmed = free_confirmed
    @warnings = []
  end

  def created? = @created

  def call
    meta = read_meta
    check_files!(meta)
    subtitle = read_subtitle(meta)
    takeaways = read_takeaways(meta)
    sections = read_sections(meta)
    deck = target_for(meta.fetch("title"))
    @created = deck.new_record?
    check_script_matches_slides
    note_missing_downloads(deck, meta)
    note_missing_pours(deck, meta["pours"])
    note_missing_takeaways(deck, takeaways)

    Presentation.transaction do
      deck.assign_attributes(
        author: deck.author || @author,
        title: meta.fetch("title"),
        description: meta["description"],
        category: meta["category"],
        difficulty: meta["difficulty"],
        duration: meta["duration"],
        content: story,
        slide_script: slide_script
      )
      deck.subtitle = subtitle if meta.key?("subtitle")
      deck.takeaways = takeaways unless takeaways.nil?
      deck.sections = sections unless sections.nil?
      deck.price = BigDecimal((meta["price"] || DEFAULT_PRICE).to_s) if @created
      deck.published = false if @created
      assign_files(deck, meta)
      deck.save!

      replace_pours(deck, meta["pours"])
      deck.tag_names = meta["tags"] if meta["tags"].present?
      if @publish && !deck.published?
        deck.free_confirmed = @free_confirmed # a $0 package publishes only with FREE=1
        deck.update!(published: true)
      end
    end

    Rails.logger.info(
      "[DeckPackageImport] #{@created ? 'created' : 'updated'} presentation #{deck.id}" \
      "#{' (explicit target)' if @into}: #{deck.slide_images.count} slides, " \
      "#{deck.presentation_bottles.count} pours, #{slide_script.size} slide script section(s), " \
      "subtitle #{meta.key?('subtitle') ? (deck.subtitle ? 'set' : 'cleared') : 'kept'}, " \
      "#{deck.parsed_what_youll_learn.size} takeaway(s)#{' (kept)' if takeaways.nil?}, " \
      "#{Array(deck.sections).size} extra section(s)#{' (kept)' if sections.nil?}, " \
      "published=#{deck.published?}, #{@warnings.size} warning(s)"
    )
    deck
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[DeckPackageImport] #{@dir.basename}: refused on save: #{e.class}: #{e.message}")
    raise Invalid, "The deck couldn't be saved: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def read_meta
    file = @dir.join("deck.json")
    refuse!("The package has no deck.json") unless file.file?

    meta = JSON.parse(file.read)
    refuse!("deck.json is not a list of deck details") unless meta.is_a?(Hash)
    %w[slug title].each { |key| refuse!("deck.json has no #{key}") if meta[key].blank? }
    meta
  rescue JSON::ParserError => e
    Rails.logger.warn("[DeckPackageImport] #{@dir.basename}: deck.json is not valid JSON (#{e.class})")
    raise Invalid, "deck.json can't be read: it is not valid JSON"
  end

  def check_files!(meta)
    slug = meta["slug"]
    missing = [ "#{slug}.pptx", "speaker-notes.md" ].reject { |name| @dir.join(name).file? }
    missing << "slides/slide-01.png" if slide_paths.empty?
    return if missing.empty?

    refuse!("The package is missing #{missing.to_sentence}")
  end

  def target_for(title)
    if @into
      other = Presentation.where(title: title).where.not(id: @into.id).first
      if other
        Rails.logger.warn("[DeckPackageImport] #{@dir.basename}: refused update of presentation #{@into.id}, " \
                          "title taken by presentation #{other.id}")
        raise TitleTaken.new("Another deck is already called \"#{title}\". Rename or delete that deck first, " \
                             "then upload the package again.", other)
      end
      return @into
    end

    existing = Presentation.find_by(title: title)
    return existing || Presentation.new unless @create_only
    return Presentation.new unless existing

    Rails.logger.warn("[DeckPackageImport] #{@dir.basename}: refused new deck, title taken by presentation #{existing.id}")
    raise TitleTaken.new("A deck called \"#{title}\" already exists. To update it, open that deck and " \
                         "use \"Replace with a package\".", existing)
  end

  def refuse!(message)
    Rails.logger.warn("[DeckPackageImport] #{@dir.basename}: refused: #{message}")
    raise Invalid, "#{message}."
  end

  def script
    @script ||= @dir.join("speaker-notes.md").read
  end

  # The script, as the story readers see: the presenter's set-up block above
  # the first rule is dropped, and "## [SLIDE 4] Title" becomes "## Title".
  def story
    text = script
    text = text.split(/^---\s*$/, 2).last if text.match?(/^---\s*$/)
    text.gsub(/^## \[SLIDE \d+\] /, "## ").strip
  end

  SLIDE_HEADING = /^## \[SLIDE \d+\][ \t]*(.*)$/

  # The script for each slide, kept beside its slide on the admin deck page:
  # one { "title", "body" } per "## [SLIDE n] Title" section, in the order the
  # sections appear (the slides are in order too). The body is the section's
  # Markdown, with a closing "---" rule dropped. Empty when the script has no
  # slide sections. Paid content: admin pages only, never a buyer page.
  def slide_script
    @slide_script ||= begin
      parts = script.split(SLIDE_HEADING, -1)
      parts.shift # whatever comes before the first section (the set-up block)
      parts.each_slice(2).map do |title, body|
        { "title" => title.to_s.strip, "body" => body.to_s.strip.sub(/\n*^-{3,}\s*\z/, "").strip }
      end
    end
  end

  def check_script_matches_slides
    sections = script.scan(/^## \[SLIDE \d+\]/).size
    return if sections == slide_paths.size

    @warnings << "The package has #{slide_paths.size} slides but the script has #{sections} [SLIDE n] sections. " \
                 "The deck was loaded; check the script against the slides."
  end

  OPTIONAL_DOWNLOADS = {
    speaker_notes: [ "-speaker-notes.pdf", "speaker notes PDF" ],
    outline_file: [ "-research-outline.pdf", "research outline PDF" ]
  }.freeze

  def note_missing_downloads(deck, meta)
    OPTIONAL_DOWNLOADS.each do |slot, (suffix, label)|
      name = "#{meta['slug']}#{suffix}"
      next if @dir.join(name).file?

      attachment = deck.public_send(slot)
      @warnings << if !@created && attachment.attached?
        "The package has no #{label} (#{name}), so the deck keeps its previous one (#{attachment.filename})."
      else
        "The package has no #{label} (#{name}), so owners won't get one."
      end
    end
  end

  # --- Takeaways and extra sections (optional keys) ---------------------------
  #
  # Each returns nil when deck.json has no such key (the deck keeps its own),
  # else the list to store. Anything malformed refuses the whole package here,
  # before the deck is touched.

  TAKEAWAYS_MAX = 10

  # The subtitle, stripped (blank clears it), or nil when the key is absent:
  # callers check meta.key?("subtitle") to tell "clear" from "keep".
  def read_subtitle(meta)
    return nil unless meta.key?("subtitle")

    value = meta["subtitle"]
    refuse!("deck.json \"subtitle\" must be text") unless value.is_a?(String)
    value = value.squish
    if value.length > Presentation::SUBTITLE_MAX
      refuse!("deck.json \"subtitle\" can be at most #{Presentation::SUBTITLE_MAX} characters (it has #{value.length})")
    end
    value.presence
  end

  TAKEAWAY_TITLE_MAX = 120
  TAKEAWAY_TEXT_MAX = 400

  def read_takeaways(meta)
    return nil unless meta.key?("takeaways")

    list = meta["takeaways"]
    refuse!("deck.json \"takeaways\" must be a list of takeaways") unless list.is_a?(Array)
    if list.size > TAKEAWAYS_MAX
      refuse!("deck.json \"takeaways\" can have at most #{TAKEAWAYS_MAX} takeaways (there are #{list.size})")
    end

    list.each.with_index(1) do |entry, n|
      unless entry.is_a?(Hash) && entry["title"].is_a?(String) && (entry["text"].nil? || entry["text"].is_a?(String))
        refuse!("deck.json \"takeaways\" needs a title and a text for takeaway #{n}")
      end

      title, text = entry["title"].squish, entry["text"].to_s.squish
      refuse!("deck.json \"takeaways\" needs a title for takeaway #{n}") if title.empty?
      if title.length > TAKEAWAY_TITLE_MAX
        refuse!("deck.json \"takeaways\" allows titles of up to #{TAKEAWAY_TITLE_MAX} characters (takeaway #{n} has #{title.length})")
      end
      if text.length > TAKEAWAY_TEXT_MAX
        refuse!("deck.json \"takeaways\" allows texts of up to #{TAKEAWAY_TEXT_MAX} characters (takeaway #{n} has #{text.length})")
      end
      # The stored format reads a line starting with one of these as the next
      # takeaway's title, so the text would not come back as written.
      if text.match?(/\A[-•*]/)
        refuse!("deck.json \"takeaways\" text can't start with a dash, a bullet or an asterisk (takeaway #{n})")
      end
    end
    list
  end

  def read_sections(meta)
    return nil unless meta.key?("sections")

    list = meta["sections"]
    refuse!("deck.json \"sections\" must be a list of sections") unless list.is_a?(Array)
    list.each.with_index(1) do |entry, n|
      next if entry.is_a?(Hash) && entry["heading"].is_a?(String) &&
              entry["lines"].is_a?(Array) && entry["lines"].all?(String)

      refuse!("deck.json \"sections\" needs a heading and a list of lines (text) for section #{n}")
    end

    sections = Presentation.normalize_sections(list)
    problems = Presentation.section_problems(sections)
    refuse!("deck.json \"sections\" #{problems.first}") if problems.any?
    sections
  end

  def note_missing_takeaways(deck, takeaways)
    return if takeaways.present?

    @warnings << if takeaways.nil? && !@created && deck.parsed_what_youll_learn.any?
      "deck.json has no takeaways, so the deck keeps the takeaways it had."
    else
      "deck.json lists no takeaways, so the deck page has no \"What you'll learn\" section."
    end
  end

  def note_missing_pours(deck, pours)
    return if pours.present?

    @warnings << if !@created && deck.presentation_bottles.exists?
      "deck.json lists no pours, so the deck keeps its existing pour list."
    else
      "deck.json lists no pours, so the deck has no pour list."
    end
  end

  def slide_paths
    @slide_paths ||= @dir.glob("slides/slide-*.png").sort
  end

  # Assigned, not attached: nothing is stored until the save, a failed save
  # stores nothing, and replaced files are purged only after the commit.
  def assign_files(deck, meta)
    slug = meta["slug"]
    assign_one(deck, :pdf_file, @dir.join("#{slug}.pptx"))
    assign_one(deck, :speaker_notes, @dir.join("#{slug}-speaker-notes.pdf"), "application/pdf")
    assign_one(deck, :outline_file, @dir.join("#{slug}-research-outline.pdf"), "application/pdf")
    assign_one(deck, :featured_image, slide_paths.first, "image/png")
    deck.slide_images = slide_paths.map do |path|
      { io: path.open("rb"), filename: path.basename.to_s, content_type: "image/png" }
    end
  end

  def assign_one(deck, slot, path, content_type = nil)
    unless path&.file?
      Rails.logger.info("[DeckPackageImport] #{@dir.basename}: no #{path&.basename}, leaving #{slot} as it is")
      return
    end

    deck.public_send("#{slot}=", { io: path.open("rb"), filename: path.basename.to_s, content_type: content_type }.compact)
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
