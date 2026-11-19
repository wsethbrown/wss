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
    @deck_categories = Presentation.published.where.not(category: [ nil, "" ]).distinct.order(:category).limit(6).pluck(:category)

    # Earlier design studies, kept for reference: ?design=next and ?design=next2.
    preview = { "next" => "index_next", "next2" => "index_next2" }[params[:design]]
    if preview && design_preview_allowed?
      Rails.logger.info "Home: rendering #{preview} design study"
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

  # Membership products/prices live in SubscriptionProducts (shared with admin
  # revenue) so pricing is never hardcoded in two places.
  def fetch_stripe_products
    SubscriptionProducts.all
  end
end
