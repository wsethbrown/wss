# The deck-news list, read-only: how many addresses are on it, waiting or
# gone, and the active addresses. Any admin tier may look. No export, delete
# or sending here.
class Admin::MailingListController < Admin::BaseController
  PER_PAGE = 50

  def index
    @active_count = MailingListSubscriber.active.count
    @waiting_count = MailingListSubscriber.awaiting_confirmation.count
    @unsubscribed_count = MailingListSubscriber.unsubscribed.count
    @subscribers = MailingListSubscriber.active.order(confirmed_at: :desc, id: :desc).page(params[:page]).per(PER_PAGE)
    Rails.logger.info "Admin mailing list viewed by user #{current_user.id} (#{@active_count} active)"
  end
end
