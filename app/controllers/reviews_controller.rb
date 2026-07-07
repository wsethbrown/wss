# The public review section (/reviews): bottle search plus the latest
# tastings feed. Member actions (edit/update/destroy) are added with the
# review CRUD work.
class ReviewsController < ApplicationController
  def index
    @bottles = Bottle.order(:name)
    @bottles = @bottles.search(params[:q]) if params[:q].present?
    @recent_reviews = Review.includes(:user, :bottle).recent_first.limit(10)
  end
end
