# The public review section (/reviews): bottle search plus the latest
# tastings feed. Member actions (edit/update/destroy) for solo reviews.
class ReviewsController < ApplicationController
  before_action :authenticate_user!, except: :index
  before_action :set_review, only: [:edit, :update, :destroy]

  def index
    @bottles = Bottle.order(:name)
    @bottles = @bottles.search(params[:q]) if params[:q].present?
    @recent_reviews = Review.includes(:user, :bottle).recent_first.limit(10)
  end

  def edit; end

  def update
    if @review.update(review_params)
      redirect_to bottle_path(@review.bottle), notice: "Review updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @review.destroy
    redirect_to bottle_path(@review.bottle), notice: "Review removed."
  end

  private

  def set_review
    @review = current_user.reviews.find(params[:id])
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes)
  end
end
