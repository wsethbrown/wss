class EventRsvpsController < ApplicationController
  include ActivityLogger

  before_action :set_event
  before_action :set_rsvp, only: [:update, :destroy]

  def create
    # Get the status from params, default to 'yes' if not provided
    status = params[:status] || 'yes'
    
    @rsvp = @event.event_rsvps.build(user: current_user, status: status, note: params[:note].presence)
    authorize @rsvp, :create?

    if @rsvp.save
      log_activity(:event_rsvp, @event, { status: status })
      notify_organizer
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
      notify_organizer if @rsvp.saved_change_to_status? || @rsvp.saved_change_to_note?
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
    Rails.logger.info "Event #{@event.id}: RSVP cancelled by user #{current_user.id}"
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
    params.require(:event_rsvp).permit(:status, :note)
  end

  # The host hears about every response (with the guest's note) unless they
  # responded to their own event or muted event emails.
  def notify_organizer
    # The organizer and the event's host (if any) both hear about replies;
    # dedup covers host == organizer, and nobody is emailed about their own.
    [@event.organizer, @event.host].compact.uniq.each do |recipient|
      next if recipient.id == current_user.id
      unless recipient.event_emails?
        Rails.logger.info "Event #{@event.id}: RSVP notification to user #{recipient.id} skipped (event emails muted)"
        next
      end

      Rails.logger.info "Event #{@event.id}: RSVP notification to user #{recipient.id} enqueued"
      EventMailer.rsvp_received(recipient, @rsvp).deliver_later
    end
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
