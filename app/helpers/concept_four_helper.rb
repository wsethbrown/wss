# Concept 4, "The Theatre of the Pour" (/concepts/4, home/concept_4,
# concept_four_controller.js). It shows exactly what the live homepage's
# story shows: this takes the frame StoryFrameHelper#story_frame already
# shaped (the featured deck, the library rows, the invite, the record) and
# adds only what the theatre draws that the frame does not, each deck's own
# pour list. There is no second selection here; a number or a name that is
# not in the database never reaches the page, except the two samples the
# live homepage also shows, labelled as samples.
module ConceptFourHelper
  POURS = 4 # glasses on the table, at most (StoryFrameHelper::SEATS)

  # frame: StoryFrameHelper#story_frame. showcase_slides: the featured deck's
  # free-preview slides (HomeHelper#hero_reel_slides).
  def concept_four(frame, showcase_slides:)
    rows = frame[:rows]
    lists = pour_lists(rows.map { |r| r[:deck] })
    decks = rows.each_with_index.map do |row, i|
      deck = row[:deck]
      picked = i == frame[:picked]
      slides = picked && showcase_slides.any? ? showcase_slides : [ row[:thumb] ].compact
      count = deck.slide_images_attachments.size
      { deck: deck, picked: picked, title: row[:title], meta: row[:meta], thumb: row[:thumb], slides: slides,
        bar: [ ("#{count} slides" if count.positive?), deck.duration.presence ].compact.join(" · "),
        pours: lists[deck.id] || [] }
    end
    invite = frame[:invite]
    record = frame[:record]
    # With no pour list to name the glasses, the table seats the invite's
    # guests, as the live homepage's table does.
    seats = decks.map { |d| d[:pours].size }.max.to_i
    seats = frame[:table] if seats.zero?
    glasses = [ seats, invite[:glasses], record[:glasses] ].max
    levels = record[:pours] ? record[:pours].map { |p| p[:level].round(3) } : (record[:kind] == :review ? [ record[:level].round(3) ] : [])
    config = { deck: decks.find { |d| d[:picked] }&.dig(:deck)&.id,
               decks: decks.to_h { |d| [ d[:deck].id, { pours: d[:pours].size, slides: d[:slides].size } ] },
               seats: seats, invite: { glasses: invite[:glasses], sample: invite[:sample] },
               record: { kind: record[:kind], levels: levels } }
    Rails.logger.info "Concept 4: deck #{config[:deck] || 'none'} of #{decks.size} (pours #{decks.map { |d| d[:pours].size }.join('/')}), " \
                      "invite #{invite[:sample] ? 'sample' : 'real'} (#{invite[:glasses]} glasses), record #{record[:kind]}#{' (sample)' if record[:sample]}, #{glasses} glass actors"
    { decks: decks, seats: seats, glasses: glasses, config: config }
  end

  private

  # { deck id => its pour list rows, in pour order, POURS at most }, one query.
  def pour_lists(decks)
    return {} if decks.empty?

    PresentationBottle.where(presentation_id: decks.map(&:id)).ordered.includes(:bottle)
                      .group_by(&:presentation_id).transform_values { |list| list.first(POURS) }
  end
end
