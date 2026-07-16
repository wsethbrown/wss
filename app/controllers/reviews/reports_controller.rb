# Flagging a review for admin attention. One report per person per review;
# re-reporting is a friendly no-op. Post-moderation by design: the review stays
# public until an admin acts from the moderation queue.
class Reviews::ReportsController < ApplicationController
  before_action :authenticate_user!

  def create
    review = Review.find(params[:review_id])
    report = ReviewReport.new(review: review, user: current_user)

    if report.save
      redirect_to review_path(review), notice: "Thanks. This review has been flagged for the admins."
    elsif current_user.review_reports.exists?(review: review)
      redirect_to review_path(review), notice: "You've already flagged this review."
    else
      redirect_to review_path(review), alert: report.errors.full_messages.to_sentence
    end
  end
end
