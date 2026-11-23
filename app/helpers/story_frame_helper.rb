# The homepage story's frame (home/_story_frame, story_frame_controller.js):
# one pinned screen whose objects travel from step to step. This shapes the
# data the homepage already loads into what each object shows at each step,
# by the same rules the static step faces use (home/index), so the frame
# never shows anything the faces would not:
#
# - The deck: the hero's showcase deck (its first slide image), else the
#   faces' fallback (no slide, the ink title slide).
# - The library: the "Latest decks" rows. When the showcase deck is not one
#   of them, it takes the last row, so the deck that shrinks out of the hero
#   lands in a row of its own.
# - The invite: the next public night with its time, place and the guests
#   who said yes; or the faces' sample invite when there is none.
# - The table: one glass per guest on the invite (at most four), so a real
#   night never shows more people than said yes; the sample invite's four.
# - The record: the verdict (top three pours, ranked by the room), else the
#   featured review, else the heading alone.
#
# The frame is presentational (aria-hidden); the static faces carry the same
# content for screen readers, without JS and in print. Strings are cut for
# the frame only (String#truncate: plain text, escaped once by the view and
# set with textContent by the controller), so a long title ends cleanly.
module StoryFrameHelper
  SEATS = 4 # glasses at the table, at most
  SAMPLE_INITIALS = %w[JM AR TK LS DW].freeze # the sample invite's guests (home/index)

  # slide_count: the showcase deck's slide count (counted once by the page).
  # verdict_reviews: the verdict night's reviews, already loaded by HomeController.
  def story_frame(showcase:, showcase_slides:, slide_count:, decks:, event:, guests:, going:, verdict_night:, verdict_rows:, verdict_reviews:, review:)
    deck = showcase || decks.first
    rows = library_rows(showcase, decks)
    picked = rows.index { |r| r[:deck] == deck } || 0
    invite = invite_shape(event, guests, going)
    record = record_shape(verdict_night, verdict_rows, verdict_reviews, review)
    table = invite[:glasses]
    shape = {
      deck: deck,
      slide: showcase_slides.first,
      hero_title: plain(showcase ? showcase.title : "Whiskey Share Society", 44),
      hero_meta: showcase ? [ "#{slide_count} slides", showcase.duration.presence ].compact.join(" · ") : "",
      rows: rows, picked: picked, invite: invite, record: record,
      # Glasses at the table, and glasses in all (a record's pours beyond the
      # table's seats rise straight into the record).
      table: table, seats: [ table, record[:glasses] ].max,
      # The deck rides along on the invite and the record only where it is
      # that night's deck (or on the sample invite, which is an illustration).
      slide_in_invite: invite[:sample] || (event.present? && deck.present? && event.presentation_id == deck.id),
      slide_in_record: record[:kind] == :verdict && deck.present? && verdict_night.presentation_id == deck.id
    }
    Rails.logger.debug { "Story frame: deck #{deck&.id || 'none'}, #{rows.size} rows (picked #{picked}), invite #{invite[:sample] ? 'sample' : "event #{event.id}"}, record #{record[:kind]}, #{table} at the table" }
    shape
  end

  private

  # Plain text cut to a length, never HTML-escaped here (the view escapes it once).
  def plain(text, length)
    text.to_s.truncate(length, separator: " ")
  end

  def library_rows(showcase, decks)
    list = decks.to_a.first(3)
    if showcase && !list.include?(showcase)
      list = list.first(2) + [ showcase ]
      Rails.logger.info "Story frame: showcase deck #{showcase.id} is not among the latest decks; it takes the last row"
    end
    list.map do |d|
      { deck: d, title: plain(d.title, 40),
        meta: [ d.category.presence, (d.price.to_f.zero? ? "Free" : number_to_currency(d.price)) ].compact.join(" · "),
        thumb: deck_cover_attachment(d) }
    end
  end

  def invite_shape(event, guests, going)
    if event
      local = event.start_time.in_time_zone(event.effective_time_zone)
      shown = going.positive? ? guests.first(SEATS) : []
      { sample: false, time: local.strftime("%a · %-l:%M %P %Z"), tag: nil, date: local.strftime("%b %-d"),
        title: plain(event.title, 24), where: plain([ event.society.name, event.location.presence ].compact.join(" · "), 34),
        going: going.positive? ? "#{going} going" : "", glasses: [ going, SEATS ].min, initials: shown.map(&:initials) }
    else
      day = Date.current.next_occurring(:friday)
      { sample: true, time: "#{day.strftime('%a')} · 7:30 pm", tag: "Sample invite", date: day.strftime("%b %-d"),
        title: "Bourbon night", where: "Your society · Your place", going: "#{SAMPLE_INITIALS.size} going",
        glasses: [ SAMPLE_INITIALS.size, SEATS ].min, initials: SAMPLE_INITIALS.first(SEATS) }
    end
  end

  def record_shape(night, rows, reviews, review)
    if rows.present?
      shown = rows.first(3)
      reviews = Array(reviews)
      profile = Review.blended_wheel(reviews)
      { kind: :verdict, glasses: shown.size, title: plain(night.title, 30), meta: plain(night.society.name, 34),
        pours: shown.map { |r| { name: plain(r[:pour].bottle.name, 22), bottle: r[:pour].bottle,
                                 score: number_with_precision(r[:mean], precision: 2, strip_insignificant_zeros: true), level: (r[:mean] / 5.0).clamp(0, 1) } },
        profile: profile, wedge_pours: wedge_pours(shown, reviews, profile) }
    elsif review
      { kind: :review, glasses: 1, title: plain(review.bottle.name, 20), meta: plain(review.bottle.distillery, 30), review: review,
        level: (review.rating.to_f / 5).clamp(0, 1), profile: review.wheel_display_profile }
    else
      { kind: :empty, glasses: 0, title: "", meta: "" }
    end
  end

  # Which pour draws which wedge of the night's wheel: each family goes to
  # the shown pour whose own tastings lean on it most (by row order on a tie).
  def wedge_pours(rows, reviews, profile)
    by_bottle = reviews.group_by(&:bottle_id)
    per_pour = rows.map { |r| Review.blended_wheel(by_bottle[r[:pour].bottle_id] || []) }
    profile.keys.index_with do |family|
      best = per_pour.each_with_index.max_by { |p, i| [ p[family].to_f, -i ] }
      best && best.first[family].to_f.positive? ? best.last : rows.size - 1
    end
  end
end
