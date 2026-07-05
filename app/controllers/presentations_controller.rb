class PresentationsController < ApplicationController
  include ActivityLogger
  
  before_action :set_presentation, only: [:show, :edit, :update, :destroy]

  def index
    # Use database presentations
    @presentations = Presentation.published.includes(:author)
    
    # Filter by search term
    if params[:search].present?
      @presentations = @presentations.search(params[:search])
    end

    # Filter by category
    if params[:category].present?
      @presentations = @presentations.by_category(params[:category])
    end

    # Filter by difficulty
    if params[:difficulty].present?
      @presentations = @presentations.by_difficulty(params[:difficulty])
    end

    # Sort
    case params[:sort]
    when 'newest'
      @presentations = @presentations.recent
    when 'rating'
      @presentations = @presentations.popular
    when 'price_low'
      @presentations = @presentations.order(:price)
    when 'price_high'
      @presentations = @presentations.order(price: :desc)
    else # 'popular' - default
      @presentations = @presentations.popular
    end
  end

  def show
    log_activity(:presentation_viewed, @presentation) if user_signed_in?
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
