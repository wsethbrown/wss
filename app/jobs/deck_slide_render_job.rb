# Renders a deck's uploaded file to per-slide PNGs off the request cycle.
# LibreOffice is heavy (a full office suite spins up), so this must never run
# inside a web worker: it runs on the `renders` queue, which has its own
# one-thread worker in config/queue.yml, apart from mail and everyday jobs.
#
# One render at a time per deck, guarded twice:
# - Solid Queue's concurrency control keeps a second job for the same deck
#   blocked (not holding a thread) while one is running.
# - A Postgres session advisory lock keyed on the deck id is the hard
#   guarantee: it also covers perform_now, other adapters and an expired
#   concurrency semaphore. A row lock (`deck.with_lock`) would hold a
#   transaction open for the whole minute-long render and block every admin
#   save of the deck; the advisory lock blocks nothing but another render,
#   and Postgres drops it if the worker dies. If it is busy, the job re-queues.
#
# The new slide set is attached before the old one is purged, so a failure at
# any point leaves the previous slides in place.
class DeckSlideRenderJob < ApplicationJob
  queue_as :renders
  limits_concurrency to: 1, key: ->(presentation_id) { "deck-render-#{presentation_id}" }, duration: 30.minutes

  LOCK_NAMESPACE = 0x0D5C # first key of pg_advisory_lock(int, int); the second is the deck id
  LOCK_RETRY_WAIT = 30.seconds

  def perform(presentation_id)
    deck = Presentation.find_by(id: presentation_id)
    unless deck
      Rails.logger.info "DeckSlideRenderJob: no-op for deck #{presentation_id}: deck not found"
      return
    end
    unless deck.pdf_file.attached?
      Rails.logger.info "DeckSlideRenderJob: no-op for deck #{deck.id}: no deck file attached"
      return
    end

    locked = with_deck_lock(deck.id) { render(deck) }
    return if locked

    Rails.logger.info "DeckSlideRenderJob: another worker is already rendering deck #{deck.id}, retrying in #{LOCK_RETRY_WAIT.inspect}"
    retry_job(wait: LOCK_RETRY_WAIT)
  end

  private

  def render(deck)
    filename = deck.pdf_file.filename.to_s
    Rails.logger.info "DeckSlideRenderJob: rendering deck #{deck.id} (#{File.extname(filename)})"

    slides = DeckImport.render_slides(deck.pdf_file.download, filename)
    old_ids = deck.slide_images_attachments.pluck(:id)

    begin
      attached = deck.slide_images.attach(slides.map { |s|
        { io: StringIO.new(s[:data]), filename: s[:filename], content_type: "image/png" }
      })
      raise DeckImport::RenderError, "could not attach slides: #{deck.errors.full_messages.to_sentence}" unless attached
    rescue StandardError
      # Drop any part of the new set that landed; the old set stays.
      deck.slide_images_attachments.where.not(id: old_ids).find_each(&:purge)
      raise
    end

    ActiveStorage::Attachment.where(id: old_ids).find_each(&:purge)
    Rails.logger.info "DeckSlideRenderJob: rendered #{slides.size} slides for deck #{deck.id} (replaced #{old_ids.size})"
  rescue StandardError => e
    Rails.logger.error "DeckSlideRenderJob: render failed for deck #{deck.id}: #{e.class}: #{e.message}"
    raise
  end

  # Yields while holding the deck's advisory lock; returns false without
  # yielding when another session holds it. `uncached`: the job runs with the
  # query cache on, which would otherwise replay an earlier lock answer.
  def with_deck_lock(deck_id)
    ActiveRecord::Base.connection_pool.with_connection do |conn|
      key = "#{LOCK_NAMESPACE}, #{Integer(deck_id)}"
      return false unless conn.uncached { conn.select_value("SELECT pg_try_advisory_lock(#{key})") }

      begin
        yield
      ensure
        conn.uncached { conn.select_value("SELECT pg_advisory_unlock(#{key})") }
      end
      true
    end
  end
end
