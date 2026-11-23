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
# Each candidate deck gets a review of a bottle no other candidate leads with:
#   1. its review bottle (Presentation#record_bottle, picked in admin): the
#      newest public review of it, preferring one that can draw a palate wheel;
#   2. else the first linked bottle on its pour list that has a public review;
#   3. else the newest public review of a bottle the others have not taken;
#   4. else, when the record is too short to give every deck its own bottle,
#      the newest public review again (logged), never an invented one.
# "Public" is the homepage's rule: a solo review, or one from a PUBLIC
# society's night whose pours are revealed (Event#pours_revealed?, no manager
# bypass). Nothing from a private or still-secret night.
#
# The record's rows (#record_reviews) are that review, then the newest other
# public reviews, one per bottle, leaving out the bottles the other candidates
# lead with; empty unless there are at least two.
class HomepageFeature
  SLOTS = 3        # decks in the rotation
  RECORD_ROWS = 3  # reviews the tasting record lists, at most
  RECENT = 20      # newest public reviews considered for the record
  PER_BOTTLE = 200 # reviews loaded for the candidates' own bottles, at most

  Pick = Struct.new(:review, :source)

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

  # The review the record leads with (nil when there is no public review).
  def review
    pick.review
  end

  # :chosen, :pour_list, :newest, :repeat or :none (see the class comment).
  def review_source
    pick.source
  end

  # True when the deck's own review bottle supplies the review: the admin
  # chose it for this deck, so it shows even when a finished night could.
  def chosen_review?
    review_source == :chosen
  end

  def record_reviews
    return [] unless review

    others = picks.each_with_index.filter_map { |p, i| p.review&.bottle_id unless i == position }
    rows = ([ review ] + recent_reviews.reject { |r| others.include?(r.bottle_id) }).uniq(&:bottle_id).first(RECORD_ROWS)
    rows.size >= 2 ? rows : []
  end

  # The newest public review of a bottle, as the homepage would show it (the
  # admin deck page says whether a review bottle has one yet).
  def self.review_of(bottle_id)
    return nil if bottle_id.blank?

    best(revealed(showable.where(bottle_id: bottle_id).includes(:event).recent_first.limit(RECENT).to_a))
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

  # Of reviews newest first: the newest that can draw a wheel, else the newest.
  def self.best(reviews)
    reviews.detect { |r| r.wheel_display_profile.any? } || reviews.first
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
    picks[position] || Pick.new(nil, :none)
  end

  # One Pick per candidate deck, in order; with no deck at all, one for the
  # record alone (the newest public review, as the homepage always showed).
  def picks
    @picks ||= begin
      list = decks.presence || [ nil ]
      picks = Array.new(list.size)
      claimed = []
      reserved = list.filter_map { |d| d&.record_bottle_id }
      by_bottle = own_bottle_reviews(list.compact)
      pours = pour_list_bottles(list.compact)

      list.each_with_index do |d, i|
        found = d&.record_bottle_id && self.class.best(by_bottle[d.record_bottle_id] || [])
        next unless found

        picks[i] = Pick.new(found, :chosen)
        claimed << found.bottle_id
      end
      list.each_with_index do |d, i|
        next if picks[i] || d.nil?

        bottle_id = (pours[d.id] || []).detect { |id| by_bottle[id].present? && !claimed.include?(id) && !reserved.include?(id) }
        next unless bottle_id

        picks[i] = Pick.new(self.class.best(by_bottle[bottle_id]), :pour_list)
        claimed << bottle_id
      end
      list.each_index do |i|
        next if picks[i]

        found = self.class.best(recent_reviews.reject { |r| claimed.include?(r.bottle_id) || reserved.include?(r.bottle_id) })
        if found
          picks[i] = Pick.new(found, :newest)
          claimed << found.bottle_id
        elsif (again = self.class.best(recent_reviews))
          picks[i] = Pick.new(again, :repeat)
          Rails.logger.info "Homepage feature: deck #{list[i]&.id || 'none'} has no public review of a bottle of its own; repeating review #{again.id} (bottle #{again.bottle_id})"
        else
          picks[i] = Pick.new(nil, :none)
        end
      end
      Rails.logger.info "Homepage feature: reviews " + list.each_with_index.map { |d, i|
        "deck #{d&.id || 'none'}: #{picks[i].review ? "review #{picks[i].review.id}, bottle #{picks[i].review.bottle_id}" : 'none'} (#{picks[i].source})"
      }.join("; ")
      picks
    end
  end

  # The newest public reviews, users, bottles and events preloaded.
  def recent_reviews
    @recent_reviews ||= self.class.revealed(self.class.showable.includes(:user, :bottle, :event).recent_first.limit(RECENT).to_a)
  end

  # { deck id => its linked pour list bottle ids, in pour order }
  def pour_list_bottles(decks)
    return {} if decks.empty?

    @pour_list_bottles ||= PresentationBottle.linked.where(presentation_id: decks.map(&:id)).ordered.pluck(:presentation_id, :bottle_id)
                                             .group_by(&:first).transform_values { |rows| rows.map(&:last) }
  end

  # { bottle id => its public reviews, newest first } for the candidates' own
  # bottles (review bottles and pour lists), loaded in one go.
  def own_bottle_reviews(decks)
    wanted = (decks.filter_map(&:record_bottle_id) + pour_list_bottles(decks).values.flatten).uniq
    return {} if wanted.empty?

    self.class.revealed(self.class.showable.where(bottle_id: wanted).includes(:user, :bottle, :event).recent_first.limit(PER_BOTTLE).to_a)
        .group_by(&:bottle_id)
  end
end
