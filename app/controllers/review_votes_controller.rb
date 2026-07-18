class ReviewVotesController < ApplicationController
  before_action :authenticate_user!

  def create
    review = Review.find(params[:review_id])
    vote = current_user.review_votes.find_or_initialize_by(review: review)
    fresh_vote = !vote.persisted?
    vote.persisted? || vote.save
    if fresh_vote && vote.persisted?
      Notification.notify!(user: review.user, actor: current_user, notifiable: review, action: "review_vote")
    end
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(review, :vote), partial: "review_votes/button", locals: { review: review.reload }) }
      format.html { redirect_back fallback_location: bottle_path(review.bottle) }
    end
  end

  def destroy
    vote = current_user.review_votes.find(params[:id])
    review = vote.review
    vote.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.replace(helpers.dom_id(review, :vote), partial: "review_votes/button", locals: { review: review.reload }) }
      format.html { redirect_back fallback_location: bottle_path(review.bottle) }
    end
  end
end
