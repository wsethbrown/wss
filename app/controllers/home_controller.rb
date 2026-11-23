class HomeController < ApplicationController
  include DesignPreview

  def index
    @stripe_products = fetch_stripe_products
    # The library rows (the face and the story frame); their covers preloaded,
    # so a row costs no queries of its own.
    @featured_presentations = Presentation.published.recent.limit(3)
                                          .includes(slide_images_attachments: { blob: :variant_records }, featured_image_attachment: { blob: :variant_records }).to_a
    # The deck to feature and the review its tasting record leads with,
    # chosen together, once, so the hero, the spotlight, the library row and
    # the record agree (HomepageFeature): an admin-featured deck, else the
    # three best sellers in turn, a day each. ?rotation=1..3 previews each
    # place (admins; anyone in development).
    @feature = HomepageFeature.new(slot: (params[:rotation] if design_preview_allowed?))
    # Real rendered slides for the hero screen: the featured deck.
    @showcase_deck = @feature.deck
    # The spotlight tile: the most recently featured published deck (even one
    # without slides, which shows its cover), else the hero's deck.
    @spotlight_deck = Presentation.published.featured.recent.first || @showcase_deck
    # Real public data for the homepage slides: the next tasting night at a
    # public society and the top-rated bottles, the same rows /reviews shows.
    @next_event = Event.upcoming.joins(:society).where(societies: { is_private: false }).includes(:society).first
    @top_bottles = Bottle.with_score.where("agg.reviewers > 0").order(Arel.sql(Bottle::SORTS.fetch("top"))).limit(3)
    # The verdict: the latest revealed night at a public society with event
    # reviews, its pours ranked by the room (slide four shows its top three in
    # place of the tasting record when there is one). Public societies only and
    # Event#pours_revealed? with no bypass, so a secret pour stays secret.
    # A deck's own review bottle comes first: the admin chose it for this deck.
    if @showcase_deck&.record_bottle_id && @feature.chosen_review?
      @verdict_night = nil
      @verdict_rows = []
      @verdict_reviews = []
      Rails.logger.info "Home: deck #{@showcase_deck.id} has a review bottle with a public review, slide four shows it in place of a verdict"
    else
      load_verdict
    end
    load_next_event_guests
    load_featured_review
    @deck_categories = Presentation.published.where.not(category: [ nil, "" ]).distinct.order(:category).limit(6).pluck(:category)

    # Earlier design studies, kept for reference: ?design=next and ?design=next2.
    preview = { "next" => "index_next", "next2" => "index_next2", "next4" => "index_next4" }[params[:design]]
    if preview && design_preview_allowed?
      Rails.logger.info "Home: rendering #{preview} design study"
      if preview == "index_next4"
        # "The night, pour by pour" study (docs/redesign/DIRECTION_NIGHT.md).
        # Public societies only, so nothing private reaches a signed-out page.
        public_events = Event.joins(:society).where(societies: { is_private: false })
        @night = public_events.upcoming.includes(:society, :host, :presentation).first
        @coming_up = public_events.upcoming.includes(:society).limit(3)
        if @night
          @night_deck = @night.presentation if @night.presentation&.published?
          # Pour names only once Event#pours_revealed? says so; the homepage
          # never uses the host/manager bypass, so a secret pour stays secret.
          @night_pours = @night.event_bottles.ordered.includes(:bottle).to_a
          @night_members = @night.society.member_count
        end
        # The verdict (@verdict_night, @verdict_rows) is loaded above for slide four.
        Rails.logger.info "Home next4: night #{@night&.id || 'none'}, verdict night #{@verdict_night&.id || 'none'}"
        @night_story_deck = @night_deck if @night_deck&.slide_images&.attached?
      end
      render preview
    end
  end

  # Standalone membership page: the "start your own whiskey club" pitch plus
  # the same plan cards the homepage shows (shared partial).
  def membership
    @stripe_products = fetch_stripe_products
  end

  def contact
  end

  private

  # The latest revealed night at a public society whose pours have event
  # reviews, ranked by GlassHelper#verdict_rows. Sets @verdict_night and
  # @verdict_rows (empty when there is no such night).
  def load_verdict
    @verdict_night = Event.joins(:society).where(societies: { is_private: false }).past.includes(:society)
                          .where(id: Review.where.not(event_id: nil).select(:event_id))
                          .limit(10).detect(&:pours_revealed?)
    @verdict_rows = []
    @verdict_reviews = []
    unless @verdict_night
      Rails.logger.debug "Home: no revealed public night with reviews, slide four shows the tasting record"
      return
    end

    # Kept for the story frame's wheel, so the night's reviews load once.
    @verdict_reviews = @verdict_night.reviews.includes(:user).recent_first.to_a
    by_bottle = @verdict_reviews.group_by(&:bottle_id)
    @verdict_rows = helpers.verdict_rows(@verdict_night.event_bottles.ordered.includes(:bottle).to_a, by_bottle)
    Rails.logger.debug "Home: verdict from event #{@verdict_night.id} (#{@verdict_rows.size} scored pours)"
  end

  # Who has said yes to @next_event, for the invite on slide three: the first
  # five (avatars) and the going count. The event page already lists these
  # names publicly; the homepage only reaches public societies' nights.
  def load_next_event_guests
    @next_event_guests = []
    @next_event_going = 0
    unless @next_event
      Rails.logger.info "Home: no upcoming public night, slide three shows the sample invite"
      return
    end

    @next_event_going = @next_event.yes_count
    @next_event_guests = @next_event.confirmed_attendees.with_attached_profile_image.limit(5).to_a
    Rails.logger.info "Home: slide three shows event #{@next_event.id} (society #{@next_event.society_id}, #{@next_event_going} going)"
  end

  # Slide four's review when there is no verdict, from HomepageFeature: the
  # featured deck's own bottle (its review bottle, else its pour list), else
  # the newest public review. Only solo reviews and reviews from a PUBLIC
  # society's night whose pours are revealed can be shown, so nothing from a
  # private or still-secret night reaches the homepage.
  #
  # With it, the tasting record's rows (@record_reviews): that review first,
  # then the newest others, one per bottle, three at most. Empty unless there
  # are at least two, when slide four keeps the one review. Their users and
  # bottles are preloaded with them.
  def load_featured_review
    @featured_review = nil
    @record_reviews = []
    return if @verdict_rows.present?

    @featured_review = @feature.review
    @record_reviews = @feature.record_reviews
    if @record_reviews.any?
      Rails.logger.info "Home: slide four lists reviews #{@record_reviews.map(&:id).join(', ')} (bottles #{@record_reviews.map(&:bottle_id).join(', ')}, #{@feature.review_source}, wheel from review #{@featured_review.id}: #{@featured_review.wheel_display_profile.any? ? 'yes' : 'no'})"
    elsif @featured_review
      Rails.logger.info "Home: slide four shows review #{@featured_review.id} (bottle #{@featured_review.bottle_id}, user #{@featured_review.user_id}, #{@feature.review_source}, wheel #{@featured_review.wheel_display_profile.any? ? 'yes' : 'no'})"
    else
      Rails.logger.info "Home: no reviews yet, slide four shows only its heading"
    end
  end

  # Membership products/prices live in SubscriptionProducts (shared with admin
  # revenue) so pricing is never hardcoded in two places.
  def fetch_stripe_products
    SubscriptionProducts.all
  end
end
