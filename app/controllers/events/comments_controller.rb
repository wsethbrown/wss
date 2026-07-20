# Table talk on an event page. Who may post is EventPolicy#comment?
# (society members / organizer / global admin); the week-after-the-night
# window is enforced by the EventComment model so it can't be bypassed.
class Events::CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def create
    authorize @event, :comment?
    comment = @event.event_comments.new(comment_params.merge(user: current_user))
    if comment.save
      notify_mentioned(comment)
    else
      @alert = comment.errors.full_messages.to_sentence
      Rails.logger.info "Event #{@event.id}: comment by user #{current_user.id} rejected: #{@alert}"
    end
    respond
  end

  def destroy
    comment = @event.event_comments.find(params[:id])
    authorize comment
    comment.destroy
    respond
  end

  private

  # Tell the people tagged in the comment. Only handles that resolve to
  # exactly one society member count, so nobody is notified on a guess
  # (see Mentions). Notification.notify! already skips self-mentions.
  def notify_mentioned(comment)
    mentioned = Mentions.users_in(comment.body, @event)
    if mentioned.empty?
      Rails.logger.info "Event #{@event.id}: comment #{comment.id} by user #{current_user.id} mentioned nobody resolvable"
      return
    end

    mentioned.each do |user|
      Notification.notify!(user: user, action: "mention", actor: current_user, notifiable: comment)
    end
    Rails.logger.info "Event #{@event.id}: comment #{comment.id} by user #{current_user.id} notified #{mentioned.size} mentioned member(s): #{mentioned.map(&:id).join(', ')}"
  rescue => e
    # A failed notification must never lose the comment that is already saved.
    Rails.logger.error "Event #{@event.id}: mention notifications failed for comment #{comment.id}: #{e.class}: #{e.message}"
  end

  def set_event
    @event = Event.find(params[:event_id])
    authorize @event, :show?
  end

  def respond
    respond_to do |format|
      format.turbo_stream { render :refresh }
      format.html { redirect_to society_event_path(@event.society, @event, anchor: "table-talk"), alert: @alert }
    end
  end

  def comment_params
    params.require(:event_comment).permit(:body)
  end
end
