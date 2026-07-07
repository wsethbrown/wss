class BottlesController < ApplicationController
  before_action :authenticate_user!, only: [:new, :create]

  def show
    @bottle = Bottle.find_by!(slug: params[:id])
    @reviews = @bottle.reviews.includes(:user).recent_first
    @my_review = current_user && @bottle.reviews.find_by(user: current_user, event_id: nil)
  end

  def search
    bottles = Bottle.search(params[:q]).order(:name).limit(8)
    render json: bottles.map { |b|
      { name: b.name, display_name: b.display_name, url: bottle_path(b), review_url: new_bottle_review_path(b) }
    }
  end

  def new
    @bottle = Bottle.new(name: params[:name])
    @near_matches = []
  end

  def create
    @bottle = Bottle.new(bottle_params)
    @bottle.created_by = current_user

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
      redirect_to bottle_path(@bottle), notice: "#{@bottle.name} is on the shelf — add your tasting."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def bottle_params
    params.require(:bottle).permit(:name, :distillery, :region, :style, :abv)
  end
end
