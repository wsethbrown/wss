# The admin deck page (admin/presentations/edit and its partials): the facts
# line in the header and the deck's file slots. Presentation only.
module AdminDeckHelper
  DOC_TYPES = "application/pdf,application/vnd.openxmlformats-officedocument.wordprocessingml.document".freeze

  # Every file slot the Files tab lists, in order. `input: false` slots have no
  # upload on this page and only appear when something is attached.
  DECK_FILE_SLOTS = [
    { slot: :pdf_file, label: "Deck file", input: true,
      accept: "application/pdf,application/vnd.openxmlformats-officedocument.presentationml.presentation,application/vnd.ms-powerpoint",
      hint: "This is what buyers download. PDF or PowerPoint, max 50MB." },
    { slot: :speaker_notes, label: "Speaker notes", input: true, accept: DOC_TYPES,
      hint: "How to present each chapter (PDF or Word)." },
    { slot: :outline_file, label: "Outline", input: true, accept: DOC_TYPES,
      hint: "The one-page run of show (PDF or Word)." },
    { slot: :scorecard, label: "Custom tasting scorecard", input: true, accept: "application/pdf",
      hint: "Upload a scorecard tailored to this deck’s pours. Optional, buyers always get the standard blank WSS scorecard to fill in either way." },
    { slot: :supplemental_materials, label: "Anything else", input: true, multiple: true,
      accept: "application/pdf,image/jpeg,image/jpg,image/png,application/vnd.ms-powerpoint,application/vnd.openxmlformats-officedocument.presentationml.presentation",
      hint: "Tasting mats, score sheets, blind-tasting wraps, each shows up by name in the buyer's downloads (max 25MB each)." },
    { slot: :featured_image, label: "Banner image", input: true, accept: "image/jpeg,image/jpg,image/png,image/gif,image/webp",
      hint: "Sits behind the hero title. Landscape works best (JPEG, PNG, GIF, or WebP, max 15MB)." },
    { slot: :sneak_peek_file, label: "Sneak peek", input: false },
    { slot: :recommendations_sheet, label: "Recommendations sheet", input: false }
  ].freeze

  # The deck as saved. After a refused save the form re-renders with the
  # admin's unsaved values (and unsaved file choices) in `deck`; everything
  # that DESCRIBES the deck (header, overview, file rows, publish block) reads
  # the saved record instead, so it never shows a file or title that isn't
  # stored.
  def admin_deck_saved(deck)
    return deck unless deck.persisted? && deck.errors.any?

    @admin_deck_saved ||= {}
    @admin_deck_saved[deck.id] ||= Presentation.find(deck.id)
  end

  # The slots to draw for this deck: upload slots always, the legacy
  # download-only ones only when a file is attached.
  def admin_deck_file_slots(deck)
    DECK_FILE_SLOTS.select { |slot| slot[:input] || deck.public_send(slot[:slot]).attached? }
  end

  # The files a buyer downloads (the banner is not one): the Files tab count.
  def admin_deck_download_count(deck)
    singles = DECK_FILE_SLOTS.reject { |s| s[:multiple] || s[:slot] == :featured_image }
                             .count { |s| deck.public_send(s[:slot]).attached? }
    singles + deck.supplemental_materials.attachments.size
  end

  # "$17.99 · 45 min · 18 slides · 3 pours · 0 purchases", leaving out what the
  # deck doesn't have (no running time, no slides, no pours). Purchases always show.
  def admin_deck_facts(deck, slides_count:, purchases_count:)
    [
      (number_to_currency(deck.price) unless deck.price.nil?),
      deck.duration_label,
      (pluralize(slides_count, "slide") if slides_count.positive?),
      (pluralize(deck.pours_count, "pour") if deck.pours_count.positive?),
      pluralize(purchases_count, "purchase")
    ].compact.join(" · ")
  end
end
