class HomeController < ApplicationController
  include DesignPreview

  def index
    @stripe_products = fetch_stripe_products
    @featured_presentations = Presentation.published.recent.limit(3)
    # The one deck to spotlight: the most recently featured published deck.
    @spotlight_deck = Presentation.published.featured.recent.first
    # Real rendered slides for the hero screen: the spotlight deck when it has
    # slides, otherwise the newest deck that does.
    with_slides = Presentation.published.joins(:slide_images_attachments).distinct
    @showcase_deck = with_slides.featured.recent.first || with_slides.recent.first
    # Real public data for the homepage slides: the next tasting night at a
    # public society and the top-rated bottles, the same rows /reviews shows.
    @next_event = Event.upcoming.joins(:society).where(societies: { is_private: false }).includes(:society).first
    @top_bottles = Bottle.with_score.where("agg.reviewers > 0").order(Arel.sql(Bottle::SORTS.fetch("top"))).limit(3)
    # The verdict: the latest revealed night at a public society with event
    # reviews, its pours ranked by the room (slide four shows its top three in
    # place of the tasting record when there is one). Public societies only and
    # Event#pours_revealed? with no bypass, so a secret pour stays secret.
    load_verdict
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
    unless @verdict_night
      Rails.logger.debug "Home: no revealed public night with reviews, slide four shows the tasting record"
      return
    end

    by_bottle = @verdict_night.reviews.includes(:user).recent_first.group_by(&:bottle_id)
    @verdict_rows = helpers.verdict_rows(@verdict_night.event_bottles.ordered.includes(:bottle).to_a, by_bottle)
    Rails.logger.debug "Home: verdict from event #{@verdict_night.id} (#{@verdict_rows.size} scored pours)"
  end

  # Membership products/prices live in SubscriptionProducts (shared with admin
  # revenue) so pricing is never hardcoded in two places.
  def fetch_stripe_products
    SubscriptionProducts.all
  end
end
