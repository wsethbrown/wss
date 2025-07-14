class EventRsvpsController < ApplicationController
  before_action :set_event
  before_action :set_rsvp, only: [:update, :destroy]

  def create
    # Get the status from params, default to 'yes' if not provided
    status = params[:status] || 'yes'
    
    @rsvp = @event.event_rsvps.build(user: current_user, status: status)
    authorize @rsvp, :create?

    if @rsvp.save
      @success_message = rsvp_success_message(status)
      @event.reload # Reload to get fresh RSVP data
      respond_to do |format|
        format.html { redirect_to @event, notice: @success_message }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to @event, alert: 'Unable to RSVP to the event.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_messages") }
      end
    end
  end

  def update
    authorize @rsvp

    if @rsvp.update(rsvp_params)
      @success_message = rsvp_success_message(@rsvp.status)
      @event.reload # Reload to get fresh RSVP data
      respond_to do |format|
        format.html { redirect_to @event, notice: @success_message }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { redirect_to @event, alert: 'Unable to update RSVP.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash-messages", partial: "shared/flash_messages") }
      end
    end
  end

  def destroy
    authorize @rsvp

    @rsvp.destroy
    redirect_to @event, notice: 'RSVP was successfully cancelled.'
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_rsvp
    @rsvp = @event.event_rsvps.find_by(user: current_user)
  end

  def rsvp_params
    params.require(:event_rsvp).permit(:status)
  end

  def rsvp_success_message(status)
    case status
    when 'yes'
      'Great! You\'re attending this event.'
    when 'maybe'
      'You\'ve marked this event as "maybe" - you can change this anytime before the event.'
    when 'no'
      'You\'ve declined this event. You can change your mind anytime before the event.'
    else
      'RSVP updated successfully.'
    end
  end
end
