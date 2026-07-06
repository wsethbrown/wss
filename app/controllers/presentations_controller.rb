class PresentationsController < ApplicationController
  include ActivityLogger
  include DesignPreview
  
  before_action :set_presentation, only: [:show, :present, :edit, :update, :destroy]

  def index
    # The library is fully empty only when there are no published decks at all —
    # distinct from "your filters matched nothing".
    @library_empty = Presentation.published.none?

    # Filter options come from the catalog itself, so a new category shows up
    # automatically and an empty one never renders a dead filter.
    @categories = Presentation.published.where.not(category: [nil, ''])
                              .distinct.order(:category).pluck(:category)
    @difficulties = %w[Beginner Intermediate Advanced] &
                    Presentation.published.distinct.pluck(:difficulty).compact

    @presentations = Presentation.published.includes(:author)
    @presentations = @presentations.search(params[:search])
    @presentations = @presentations.by_category(params[:category])
    @presentations = @presentations.by_difficulty(params[:difficulty])

    @presentations = case params[:sort]
                     when 'newest'     then @presentations.recent
                     when 'price_low'  then @presentations.order(:price)
                     when 'price_high' then @presentations.order(price: :desc)
                     else                   @presentations.popular
                     end

    @presentations = @presentations.page(params[:page]).per(12)

    maybe_render_next
  end

  def show
    # Page views are deliberately not logged: one ActivityLog row (with IP+UA)
    # per authenticated view was over half the table and nothing consumed it.

    # Reading access: owners (with valid access) and admins read the whole
    # story; everyone else gets a teaser that fades into the purchase CTA.
    @full_story = user_signed_in? && @presentation.can_download_full_presentation?(current_user)

    @more_decks = Presentation.published.where.not(id: @presentation.id).recent.limit(3)
  end

  # Full-screen in-browser slide player — the tasting venue. Owners/admins only.
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

  def set_presentation
    @presentation = Presentation.find(params[:id])
  end

  def presentation_params
    params.require(:presentation).permit(:title, :description, :content, :price, :category)
  end
end
