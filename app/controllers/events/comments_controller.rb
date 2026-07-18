# Table talk on an event page. Who may post is EventPolicy#comment?
# (society members / organizer / global admin); the week-after-the-night
# window is enforced by the EventComment model so it can't be bypassed.
class Events::CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def create
    authorize @event, :comment?
    comment = @event.event_comments.new(comment_params.merge(user: current_user))
    unless comment.save
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
