# The homepage's featured deck and the review its tasting record leads with,
# chosen together, once per page, so the hero, the spotlight, the library row
# and the record all show the same deck and its own bottle.
#
# WHICH DECK
# - A deck an admin marked "Feature this deck" always wins (the most recently
#   created published one that has rendered slides).
# - With none featured, the three best-selling published decks take turns, a
#   day each (ROTATION). The same deck for every visitor all day, so pages and
#   caches agree; the next day the next deck.
#
# WHAT A SALE IS
# - A paid purchase, or a credit unlock. One per buyer (a deck is owned once).
# - Not a free claim ($0), or a free deck would outrank everything sold.
# - Not a copy owned by an admin account: those are test purchases. Admins'
#   ordinary access writes no ownership row, so it never counted anyway, and
#   neither does a member opening a deck included with membership.
# - Ties go to the newer deck. Decks with no sales fill the places left, newest
#   first, so with no sales at all the three newest decks rotate; with fewer
#   than three decks the rotation is as long as the list.
# - Only published decks with rendered slides: the hero shows the slides.
#
# WHICH REVIEW
# Each candidate deck gets a review of a bottle no other candidate leads with,
# with nothing for an admin to pick:
#   1. the highest-rated bottle on its pour list (its linked catalog bottles):
#      highest mean score across the bottle's public reviews, ties to the
#      bottle with more reviews, then the earlier pour. The review shown is
#      that bottle's best-scoring public review (ties: one that can draw a
#      palate wheel, then the newest). Decks with the fewest reviewed bottles
#      choose first, so one deck does not take another's only bottle;
#   2. else none: the record shows the sample review (SAMPLE), a hardcoded
#      illustration labelled "Sample review", never passed off as a tasting.
# "Public" is the homepage's rule: a solo review, or one from a PUBLIC
# society's night whose pours are revealed (Event#pours_revealed?, no manager
# bypass). Nothing from a private or still-secret night.
#
# The record's rows (#record_reviews) are that review, then the newest other
# public reviews, one per bottle, leaving out the bottles the other candidates
# lead with; empty unless there are at least two, and always with the sample.
class HomepageFeature
  SLOTS = 3        # decks in the rotation
  RECORD_ROWS = 3  # reviews the tasting record lists, at most
  RECENT = 20      # newest public reviews considered for the record
  PER_BOTTLE = 200 # reviews loaded for the candidates' pour list bottles, at most

  Pick = Struct.new(:review, :source)

  # The sample review: what the tasting record shows when the featured deck
  # has no publicly reviewed bottle on its pour list. The owner's choice of
  # bottle; the score and the wheel are an illustration, which is why every
  # place that draws it says "Sample review" and links nowhere. It answers the
  # few questions the record asks of a review.
  SampleReview = Struct.new(:bottle_name, :rating, :wheel, keyword_init: true) do
    def wheel_display_profile = wheel
    def notes = nil
    def nose = nil
    def palate = nil
    def finish = nil
  end
  SAMPLE = SampleReview.new(bottle_name: "Weller Antique 107", rating: 4.0,
                            wheel: { "sweet" => 0.9, "oaky" => 0.6, "fruity" => 0.5, "spicy" => 0.4, "grainy" => 0.3 }.freeze).freeze

  # day: the rotation's day. slot: 1..SLOTS to ask for one candidate by place
  # (an admin preview); ignored when it names no candidate or a deck is featured.
  def initialize(day: Date.current, slot: nil)
    @day = day
    @slot = slot.to_i
  end

  # The candidates: the featured deck alone, or the rotation in selling order.
  def decks
    load_decks
    @decks
  end

  # :featured (an admin's pick), :rotation (best sellers in turn) or :none.
  def source
    load_decks
    @source
  end

  # { deck id => sales } for the rotation's candidates (empty when featured).
  def sales
    load_decks
    @sales
  end

  # Today's place in the rotation, from 0.
  def position
    return 0 if decks.size < 2
    return @slot - 1 if @slot.between?(1, decks.size) && source == :rotation

    @day.jd % decks.size
  end

  def deck
    decks[position]
  end

  # The review the record leads with: the featured deck's highest rated
  # bottle. Nil when the deck has none, and the record shows #sample.
  def review
    pick.review
  end

  # SAMPLE when there is no review to lead with, else nil.
  def sample
    SAMPLE unless review
  end

  # :deck (a bottle on the deck's pour list) or :sample.
  def review_source
    pick.source
  end

  # True when the featured deck's own pour list supplies the review: the
  # record then shows it even when a finished night could. Asks only about
  # the decks' own bottles, so the newest reviews load only when needed.
  def deck_review?
    deck_picks[position].present?
  end

  def record_reviews
    return [] unless review

    others = picks.each_with_index.filter_map { |p, i| p.review&.bottle_id unless i == position }
    rows = ([ review ] + recent_reviews.reject { |r| others.include?(r.bottle_id) }).uniq(&:bottle_id).first(RECORD_ROWS)
    rows.size >= 2 ? rows : []
  end

  # Reviews that may appear on the homepage, before the reveal check.
  def self.showable
    public_nights = Event.joins(:society).where(societies: { is_private: false }).select(:id)
    Review.where(event_id: nil).or(Review.where(event_id: public_nights))
  end

  def self.revealed(reviews)
    skipped = reviews.select { |r| r.event && !r.event.pours_revealed? }
    Rails.logger.info "Homepage feature: skipped #{skipped.size} review(s) from unrevealed nights (#{skipped.map(&:id).join(', ')})" if skipped.any?
    reviews - skipped
  end

  private

  def load_decks
    return if @decks

    with_slides = Presentation.published.where(id: Presentation.joins(:slide_images_attachments).select(:id))
    featured = with_slides.featured.recent.first
    @sales = {}
    if featured
      @decks = [ featured ]
      @source = :featured
      Rails.logger.info "Homepage feature: deck #{featured.id} (featured by an admin)"
      return
    end

    @decks = best_sellers(with_slides)
    @source = @decks.any? ? :rotation : :none
    @sales = @decks.to_h { |d| [ d.id, d.sold_count.to_i ] }
    if @decks.any?
      Rails.logger.info "Homepage feature: rotation of #{@decks.size} (#{@sales.map { |id, n| "deck #{id}: #{n} sold" }.join(', ')}), " \
                        "place #{position + 1} on #{@day}#{' (asked for by slot)' if @slot.between?(1, @decks.size)}: deck #{deck.id}"
    else
      Rails.logger.info "Homepage feature: no published deck with slides, nothing to feature"
    end
  end

  def best_sellers(scope)
    sold = UserPresentation.joins(:user).where(users: { admin_role: "none" })
                           .where("user_presentations.purchase_type = 'credit' OR user_presentations.purchase_price IS NULL OR user_presentations.purchase_price > 0")
                           .group(:presentation_id).select("user_presentations.presentation_id, COUNT(*) AS sold")
    scope.joins("LEFT JOIN (#{sold.to_sql}) sales ON sales.presentation_id = presentations.id")
         .select("presentations.*, COALESCE(sales.sold, 0) AS sold_count")
         .order(Arel.sql("COALESCE(sales.sold, 0) DESC"), created_at: :desc, id: :desc)
         .limit(SLOTS).to_a
  end

  def pick
    picks[position] || Pick.new(nil, :sample)
  end

  def candidates
    decks.presence || [ nil ]
  end

  # Step 1 for every candidate: [Pick or nil] by place.
  def deck_picks
    @deck_picks ||= begin
      list = decks
      picks = Array.new(candidates.size)
      by_bottle = own_bottle_reviews(list)
      pours = pour_list_bottles(list)
      reviewed = list.to_h { |d| [ d.id, (pours[d.id] || []).select { |id| by_bottle[id].present? } ] }
      claimed = []
      # Fewest reviewed bottles first (then selling order), so a deck with one
      # option keeps it.
      list.each_with_index.sort_by { |d, i| [ reviewed[d.id].size, i ] }.each do |d, i|
        open = reviewed[d.id] - claimed
        next if open.empty?

        bottle_id = open.each_with_index.max_by { |id, at| [ mean(by_bottle[id]), by_bottle[id].size, -at ] }.first
        picks[i] = Pick.new(top_review(by_bottle[bottle_id]), :deck)
        claimed << bottle_id
      end
      picks
    end
  end

  def mean(reviews)
    reviews.sum { |r| r.rating.to_f } / reviews.size
  end

  # Of one bottle's reviews (newest first): the best score, then one that can
  # draw a wheel, then the newest.
  def top_review(reviews)
    reviews.each_with_index.min_by { |r, at| [ -r.rating.to_f, r.wheel_display_profile.any? ? 0 : 1, at ] }.first
  end

  # One Pick per candidate deck, in order (with no deck at all, one for the
  # record alone): the deck's own bottle, else the sample.
  def picks
    @picks ||= begin
      picks = deck_picks.map { |p| p || Pick.new(nil, :sample) }
      Rails.logger.info "Homepage feature: reviews " + candidates.each_with_index.map { |d, i|
        "deck #{d&.id || 'none'}: #{picks[i].review ? "review #{picks[i].review.id}, bottle #{picks[i].review.bottle_id}" : 'the sample review'}"
      }.join("; ")
      picks
    end
  end

  # The newest public reviews (the record's other rows), users, bottles and
  # events preloaded.
  def recent_reviews
    @recent_reviews ||= self.class.revealed(self.class.showable.includes(:user, :bottle, :event).recent_first.limit(RECENT).to_a)
  end

  # { deck id => its linked pour list bottle ids, in pour order }
  def pour_list_bottles(decks)
    return {} if decks.empty?

    @pour_list_bottles ||= PresentationBottle.linked.where(presentation_id: decks.map(&:id)).ordered.pluck(:presentation_id, :bottle_id)
                                             .group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end

  # { bottle id => its public reviews, newest first } for the bottles on the
  # candidates' pour lists, loaded in one go.
  def own_bottle_reviews(decks)
    wanted = pour_list_bottles(decks).values.flatten.uniq
    return {} if wanted.empty?

    self.class.revealed(self.class.showable.where(bottle_id: wanted).includes(:user, :bottle, :event).recent_first.limit(PER_BOTTLE).to_a)
        .group_by(&:bottle_id)
  end
end
