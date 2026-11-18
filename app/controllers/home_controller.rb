class HomeController < ApplicationController
  include DesignPreview

  def index
    # Fetch Stripe products for pricing display
    @stripe_products = fetch_stripe_products
    @featured_presentations = Presentation.published.recent.limit(3)
    # The one deck to spotlight right now: the most recently featured published deck.
    @spotlight_deck = Presentation.published.featured.recent.first

    if render_next_design?
      # Preview homepage shows real rendered slides from the newest deck that has them.
      @showcase_deck = Presentation.published.recent.joins(:slide_images_attachments).distinct.first
      # Real public data for the step tiles: the next tasting night at a public
      # society and the top-rated bottles, the same rows /reviews shows everyone.
      @next_event = Event.upcoming.joins(:society).where(societies: { is_private: false }).includes(:society).first
      @top_bottles = Bottle.with_score.where("agg.reviewers > 0").order(Arel.sql(Bottle::SORTS.fetch("top"))).limit(3)
      Rails.logger.info "Home: rendering next-design preview (showcase deck #{@showcase_deck&.id || 'none'})"
      render "index_next"
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

  # Membership products/prices live in SubscriptionProducts (shared with admin
  # revenue) so pricing is never hardcoded in two places.
  def fetch_stripe_products
    SubscriptionProducts.all
  end
end
