class PresentationsController < ApplicationController
  include ActivityLogger
  include DesignPreview
  
  before_action :set_presentation, only: [:show, :present, :edit, :update, :destroy]

  def index
    # The library is fully empty only when there are no published decks at all,
    # distinct from "your filters matched nothing".
    @library_empty = Presentation.published.none?

    # Filter options come from the catalog itself, so a new category shows up
    # automatically and an empty one never renders a dead filter.
    @categories = Presentation.published.where.not(category: [nil, ''])
                              .distinct.order(:category).pluck(:category)
    @popular_tags = Tag.joins(:presentation_tags).group('tags.id')
                       .order(Arel.sql('COUNT(presentation_tags.id) DESC')).limit(12)
    @difficulties = %w[Beginner Intermediate Advanced] &
                    Presentation.published.distinct.pluck(:difficulty).compact

    @presentations = Presentation.published.includes(:author)
    @presentations = @presentations.search(params[:search])
    @presentations = @presentations.by_category(params[:category])
    @presentations = @presentations.by_difficulty(params[:difficulty])
    @presentations = @presentations.by_tag(params[:tag])

    @presentations = case params[:sort]
                     when 'newest'     then @presentations.recent
                     when 'price_low'  then @presentations.order(:price)
                     when 'price_high' then @presentations.order(price: :desc)
                     # Default view pins featured decks to the top, then popularity.
                     else                   @presentations.order(featured: :desc).popular
                     end

    @presentations = @presentations.page(params[:page]).per(12)

    maybe_render_next
  end

  def show
    # Page views are deliberately not logged: one ActivityLog row (with IP+UA)
    # per authenticated view was over half the table and nothing consumed it.

    # Returning from Stripe Checkout: verify and grant here, then redirect to
    # the clean URL so the message is a real flash (one showing, gone on
    # refresh) instead of a banner the query string keeps resurrecting.
    return if handle_checkout_return

    # Reading access: owners (with valid access) and admins read the whole
    # story; everyone else gets a teaser that fades into the purchase CTA.
    @full_story = user_signed_in? && @presentation.can_download_full_presentation?(current_user)

    @more_decks = Presentation.published.where.not(id: @presentation.id).recent.limit(3)

    maybe_render_next
  end

  # Full-screen in-browser slide player, the tasting venue. Owners/admins only.
  def present
    unless user_signed_in? && @presentation.can_download_full_presentation?(current_user) &&
           @presentation.slide_images.attached?
      redirect_to presentation_path(@presentation) and return
    end
    render layout: false
  end

  def new
    @presentation = Presentation.new
    authorize @presentation
  end

  def create
    @presentation = current_user.presentations.build(presentation_params)
    authorize @presentation

    if @presentation.save
      redirect_to @presentation, notice: 'Presentation was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @presentation
  end

  def update
    authorize @presentation

    if @presentation.update(presentation_params)
      redirect_to @presentation, notice: 'Presentation was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @presentation

    @presentation.destroy
    redirect_to presentations_url, notice: 'Presentation was successfully deleted.'
  end

  private

  # Stripe sends the buyer back with ?purchase=success&session_id=... We
  # confirm the payment with Stripe and grant access on the spot (the webhook
  # stays the backstop, and both are idempotent). Returns true when it has
  # redirected. Never trusts the query string alone: the old banner claimed
  # "you now have access" on any URL carrying purchase=success.
  def handle_checkout_return
    return false if params[:purchase].blank?

    if params[:purchase] == "cancelled"
      redirect_to presentation_path(@presentation), alert: "Purchase cancelled. You can try again any time." and return true
    end
    return false unless params[:purchase] == "success"

    unless user_signed_in?
      redirect_to presentation_path(@presentation) and return true
    end

    if params[:session_id].present? && !@presentation.purchased_by?(current_user)
      begin
        session = Stripe::Checkout::Session.retrieve(params[:session_id])
        Presentations::CheckoutFulfillment.fulfill!(session, expected_user: current_user)
      rescue Stripe::StripeError => e
        Rails.logger.error "Checkout return for presentation #{@presentation.id}, user #{current_user.id}: Stripe lookup failed: #{e.message}"
      end
    end

    if @presentation.reload.purchased_by?(current_user)
      Rails.logger.info "Checkout return: user #{current_user.id} confirmed owning presentation #{@presentation.id}"
      redirect_to presentation_path(@presentation), notice: "Purchase complete. #{@presentation.title} is yours." and return true
    end

    # Paid but not yet granted: the webhook is still the safety net, so say
    # something true rather than promising access we can't see.
    Rails.logger.warn "Checkout return: user #{current_user.id} has no purchase row yet for presentation #{@presentation.id}; webhook pending"
    redirect_to presentation_path(@presentation),
                alert: "Payment received. Your deck is still unlocking, refresh in a moment and it will be here." and return true
  end

  def set_presentation
    @presentation = Presentation.find(params[:id])
    ensure_deck_visible!
  end

  # Drafts exist only in the admin panel: to customers they 404 as if they
  # don't exist (no existence leak). Admins see them with a draft banner.
  def ensure_deck_visible!
    raise ActiveRecord::RecordNotFound unless @presentation.published? || current_user&.admin?
  end

  def presentation_params
    params.require(:presentation).permit(:title, :description, :content, :price, :category)
  end
end
