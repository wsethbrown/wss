# Deck reviews. Eligibility (purchased OR attended a finished night that ran
# the deck) is validated in the model; this controller only owns identity:
# you write, edit, and delete your own review.
class Presentations::ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_presentation

  def create
    review = @presentation.presentation_reviews.build(review_params.merge(user: current_user))
    if review.save
      Rails.logger.info "Deck review #{review.id} created: deck #{@presentation.id} rated #{review.rating} by user #{current_user.id}"
      redirect_to presentation_path(@presentation, anchor: "reviews"), notice: "Thanks, your review is up."
    else
      # Usually the eligibility gate (neither owner nor attendee) or a repeat.
      Rails.logger.warn "Deck review refused: user #{current_user.id} on deck #{@presentation.id}: #{review.errors.full_messages.to_sentence}"
      redirect_to presentation_path(@presentation, anchor: "reviews"), alert: review.errors.full_messages.to_sentence
    end
  end

  def update
    review = current_user.presentation_reviews.find(params[:id])
    if review.update(review_params)
      Rails.logger.info "Deck review #{review.id} updated: deck #{@presentation.id} now rated #{review.rating} by user #{current_user.id}"
      redirect_to presentation_path(@presentation, anchor: "reviews"), notice: "Review updated."
    else
      Rails.logger.warn "Deck review #{review.id} update refused for user #{current_user.id}: #{review.errors.full_messages.to_sentence}"
      redirect_to presentation_path(@presentation, anchor: "reviews"), alert: review.errors.full_messages.to_sentence
    end
  end

  def destroy
    review = current_user.presentation_reviews.find(params[:id])
    review.destroy
    Rails.logger.info "Deck review #{review.id} removed by its author (user #{current_user.id}, deck #{@presentation.id})"
    redirect_to presentation_path(@presentation, anchor: "reviews"), notice: "Review removed."
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:presentation_id])
  end

  def review_params
    params.require(:presentation_review).permit(:rating, :body)
  end
end
