# Dismissing a report keeps the review and closes every open report on it
# (one decision per review, not per reporter). Removing the reported review
# goes through the existing admin review destroy, which is delete-gated.
class Admin::ReviewReportsController < Admin::BaseController
  def dismiss
    report = ReviewReport.find(params[:id])
    ReviewReport.open_reports.where(review_id: report.review_id)
                .update_all(status: "dismissed", updated_at: Time.current)
    redirect_to admin_moderation_path, notice: "Report dismissed. The review stays up."
  end
end
