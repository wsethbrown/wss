# Data shaping for the glass glyph (app/views/shared/_glass.html.erb): the
# table (one glass per seat) and the verdict (a night's pours ranked by the
# room). Both work on records the caller already loaded, so a page pays for
# them once, never per row.
module GlassHelper
  TABLE_SEATS_SHOWN = 12

  # RSVP answers for one event in a single grouped query:
  # { "yes" => 3, "maybe" => 1, "no" => 2 }.
  def rsvp_tally(event)
    event.event_rsvps.group(:status).count
  end

  # Glass levels for the table: going is a full glass, maybe half, unanswered
  # empty. "No" is not a seat. `unanswered` is nil when the viewer may not see
  # it (the page shows that count to society members only).
  # Returns [levels, seats not drawn].
  def table_seat_levels(yes:, maybe:, unanswered: nil)
    levels = Array.new(yes.to_i, 1.0) + Array.new(maybe.to_i, 0.5) + Array.new(unanswered.to_i, 0.0)
    [ levels.first(TABLE_SEATS_SHOWN), [ levels.size - TABLE_SEATS_SHOWN, 0 ].max ]
  end

  # The verdict: the night's pours ranked by the room's mean event-review
  # score (event-tagged reviews only, as on the event page), best first, ties
  # in serve order. `number` is the order the pour was served.
  # pours: the event's EventBottles in serve order (EventBottle.ordered).
  # reviews_by_bottle: that event's reviews grouped by bottle_id.
  def verdict_rows(pours, reviews_by_bottle)
    pours.each_with_index.filter_map do |pour, i|
      reviews = reviews_by_bottle[pour.bottle_id]
      next if reviews.blank?

      { pour: pour, number: i + 1, mean: (reviews.sum(&:rating) / reviews.size).to_f.round(2),
        count: reviews.size, note: reviews.detect { |r| r.notes.present? } }
    end.sort_by { |row| [ -row[:mean], row[:number] ] }
  end
end
