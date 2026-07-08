class BottlesController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]

  def show
    @bottle = Bottle.find_by!(slug: params[:id])
    @reviews = @bottle.reviews.includes(:user, event: [:society, :event_bottles]).order(votes_count: :desc, created_at: :desc).page(params[:page]).per(10)
    @my_review = current_user && @bottle.reviews.find_by(user: current_user, event_id: nil)
  end

  def search
    bottles = Bottle.search(params[:q]).order(:name).limit(8)
    render json: bottles.map { |b|
      { id: b.id, name: b.name, display_name: b.display_name,
        url: bottle_path(b), review_url: new_bottle_review_path(b) }
    }
  end

  def new
    @bottle = Bottle.new(name: params[:name])
    @near_matches = []
    @return_to = safe_return_to
  end

  def create
    @bottle = Bottle.new(bottle_params)
    @bottle.created_by = current_user
    @return_to = safe_return_to

    # Soft dedup: same search the autocomplete uses. The user can click an
    # existing bottle instead, or confirm theirs is genuinely different.
    @near_matches =
      if params[:confirmed_duplicate] == "1" || @bottle.name.blank?
        []
      else
        Bottle.search(@bottle.name).limit(5)
      end
    if @near_matches.any?
      render :new, status: :unprocessable_entity
      return
    end

    if @bottle.save
      if @return_to
        redirect_to @return_to, notice: "#{@bottle.name} is on the shelf."
      else
        redirect_to bottle_path(@bottle), notice: "#{@bottle.name} is on the shelf — add your tasting."
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def bottle_params
    params.require(:bottle).permit(:name, :distillery, :region, :style, :abv, :label_image)
  end

  # Only same-app paths may round-trip through the add-a-bottle flow (e.g.
  # back to an event's pour list). "//host" and absolute URLs are dropped.
  def safe_return_to
    path = params[:return_to].to_s
    path if path.start_with?("/") && !path.start_with?("//")
  end
end
