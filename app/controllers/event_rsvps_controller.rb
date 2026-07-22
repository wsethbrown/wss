class EventRsvpsController < ApplicationController
  include ActivityLogger

  before_action :set_event
  before_action :set_rsvp, only: [ :update, :destroy ]

  # Answering is idempotent: the segmented control posts here every time,
  # whether or not an RSVP already exists. It has to, because the control is
  # client-owned and never re-rendered (see events/_rsvp_buttons), so its form
  # action can't switch from create to update after the first answer. Read this
  # as "set my answer", not "create a record".
  def create
    status = params[:status] || "yes"
    @rsvp = @event.event_rsvps.find_or_initialize_by(user: current_user)
    existing = @rsvp.persisted?

    @rsvp.status = status
    @rsvp.note = params[:note].presence if params.key?(:note)
    authorize @rsvp, existing ? :update? : :create?

    if save_answer
      log_activity(:event_rsvp, @event, { status: status }) unless existing
      notify_organizer if @rsvp.saved_change_to_status? || @rsvp.saved_change_to_note?
      Rails.logger.info "Event #{@event.id}: RSVP #{existing ? 'changed' : 'recorded'} as #{status} by user #{current_user.id}"
      @success_message = rsvp_success_message(status)
      @event.reload # Reload to get fresh RSVP data
      respond_to do |format|
        format.html { redirect_to @event, notice: @success_message }
        format.turbo_stream
      end
    else
      Rails.logger.warn "Event #{@event.id}: RSVP by user #{current_user.id} refused: #{@rsvp.errors.full_messages.to_sentence}"
      respond_to do |format|
        format.html { redirect_to @event, alert: "Unable to RSVP to the event." }
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash-messages", partial: "shared/flash_messages") }
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
        format.html { redirect_to @event, alert: "Unable to update RSVP." }
        format.turbo_stream { render turbo_stream: turbo_stream.update("flash-messages", partial: "shared/flash_messages") }
      end
    end
  end

  def destroy
    authorize @rsvp

    @rsvp.destroy
    Rails.logger.info "Event #{@event.id}: RSVP cancelled by user #{current_user.id}"
    redirect_to @event, notice: "RSVP was successfully cancelled."
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  # Double-clicking the control can put two creates in flight at once; the
  # unique index catches the loser, so treat it as the change it meant to be
  # rather than surfacing a database error.
  def save_answer
    @rsvp.save
  rescue ActiveRecord::RecordNotUnique
    Rails.logger.info "Event #{@event.id}: concurrent RSVP by user #{current_user.id}, applying as a change"
    @rsvp = @event.event_rsvps.find_by(user: current_user)
    @rsvp.present? && @rsvp.update(status: params[:status] || "yes")
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
    [ @event.organizer, @event.host ].compact.uniq.each do |recipient|
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
    when "yes"
      "Great! You're attending this event."
    when "maybe"
      'You\'ve marked this event as "maybe" - you can change this anytime before the event.'
    when "no"
      "You've declined this event. You can change your mind anytime before the event."
    else
      "RSVP updated successfully."
    end
  end
end
