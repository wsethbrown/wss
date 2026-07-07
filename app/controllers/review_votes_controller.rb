class ReviewVotesController < ApplicationController
  before_action :authenticate_user!

  def create
    review = Review.find(params[:review_id])
    vote = current_user.review_votes.find_or_initialize_by(review: review)
    if vote.persisted? || vote.save
      redirect_to review_path(review), notice: "Voted."
    else
      redirect_to review_path(review), alert: vote.errors.full_messages.to_sentence
    end
  end

  def destroy
    vote = current_user.review_votes.find(params[:id])
    review = vote.review
    vote.destroy
    redirect_to review_path(review)
  end
end
