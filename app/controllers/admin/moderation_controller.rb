# The moderation queue: everything a member has flagged or proposed, in one
# place. Two feeds: open review reports (dismiss keeps the review; removal is
# the existing hard-delete, full admins only) and pending bottle-edit proposals
# (apply/reject live on each bottle's admin page).
class Admin::ModerationController < Admin::BaseController
  def index
    @open_reports = ReviewReport.open_reports
                                .includes(review: [ :user, :bottle ])
                                .order(created_at: :desc)
                                .group_by(&:review)

    @pending_edits = BottleEdit.pending
                               .includes(:bottle, :user)
                               .order(created_at: :desc)
  end
end
