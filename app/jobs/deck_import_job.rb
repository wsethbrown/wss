# Drafts a .ppt/.pdf import's text (LibreOffice -> PDF -> pdftotext) in the
# jobs process, on the `renders` queue, so the web request that created the
# draft never runs those tools (I4). The admin may already be editing the
# draft: only fields still holding the import placeholder are filled.
class DeckImportJob < ApplicationJob
  queue_as :renders
  limits_concurrency to: 1, key: ->(presentation_id) { "deck-import-#{presentation_id}" }, duration: 15.minutes

  FIELDS = %i[title description content slides_preview].freeze

  def perform(presentation_id)
    deck = Presentation.find_by(id: presentation_id)
    unless deck&.pdf_file&.attached?
      Rails.logger.info "DeckImportJob: no-op for deck #{presentation_id}: #{deck ? 'no deck file attached' : 'deck not found'}"
      return
    end

    filename = deck.pdf_file.filename.to_s
    Rails.logger.info "DeckImportJob: extracting text for deck #{deck.id} (#{File.extname(filename)})"
    parsed = DeckImport.parse(deck.pdf_file.download, filename)
    placeholder = DeckImport.placeholder(filename)

    extracted = {
      title: parsed.title,
      description: parsed.description,
      content: parsed.content.presence || parsed.description.presence || parsed.title,
      slides_preview: parsed.slides_preview
    }
    changes = FIELDS.each_with_object({}) do |field, h|
      h[field] = extracted[field] if deck.public_send(field).to_s == placeholder.public_send(field).to_s
    end
    kept = FIELDS - changes.keys

    if changes.empty?
      Rails.logger.info "DeckImportJob: no-op for deck #{deck.id}: every field already edited"
      return
    end

    deck.update!(changes)
    Rails.logger.info "DeckImportJob: filled #{changes.keys.join(', ')} for deck #{deck.id}" \
                      "#{kept.any? ? " (kept edited #{kept.join(', ')})" : ''}"
  rescue StandardError => e
    Rails.logger.error "DeckImportJob: text extraction failed for deck #{presentation_id}: #{e.class}: #{e.message}"
    raise
  end
end
