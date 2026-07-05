# Renders a deck's uploaded file to per-slide PNGs off the request cycle.
# LibreOffice is heavy (a full office suite spins up), so this must never run
# inside a web worker — it belongs in the jobs process.
class DeckSlideRenderJob < ApplicationJob
  queue_as :default

  def perform(presentation_id)
    deck = Presentation.find_by(id: presentation_id)
    return unless deck&.pdf_file&.attached?

    data = deck.pdf_file.download
    slides = DeckImport.render_slides(data, deck.pdf_file.filename.to_s)
    return if slides.empty?

    deck.slide_images.purge if deck.slide_images.attached?
    slides.each do |s|
      deck.slide_images.attach(io: StringIO.new(s[:data]), filename: s[:filename], content_type: "image/png")
    end
  end
end
