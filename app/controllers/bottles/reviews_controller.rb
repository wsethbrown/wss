# Creating a review in the context of a bottle (solo tastings — Phase 1).
# Event-tagged creation arrives in Phase 2 via the event page.
class Bottles::ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bottle

  def new
    @review = @bottle.reviews.new
  end

  def create
    @review = @bottle.reviews.new(review_params)
    @review.user = current_user

    if @review.save
      redirect_to review_path(@review), notice: "Your tasting is on the record."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes, :price_paid, flavor_wheel: Review::DESCRIPTOR_LEXICON.keys, images: [])
  end
end
