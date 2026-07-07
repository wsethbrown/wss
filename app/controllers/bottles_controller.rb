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
      { name: b.name, display_name: b.display_name, url: bottle_path(b) }
    }
  end

  # new/create arrive in Task 4; stubs keep the routes honest until then.
  def new
    @bottle = Bottle.new(name: params[:name])
  end

  def create
    head :unprocessable_entity
  end
end
