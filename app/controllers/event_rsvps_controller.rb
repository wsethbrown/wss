class EventRsvpsController < ApplicationController
  include ActivityLogger

  before_action :authenticate_user!
  before_action :set_event
  before_action :set_rsvp, only: [ :update, :destroy ]
  after_action :verify_authorized

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
      reason = @rsvp.errors.full_messages.to_sentence.presence || "Unable to RSVP to the event."
      respond_to do |format|
        format.html { redirect_to @event, alert: reason }
        # A failed status lets the segmented control put the old answer back.
        format.turbo_stream do
          flash.now[:alert] = reason
          render turbo_stream: turbo_stream.update("flash-messages", partial: "shared/flash_messages"),
                 status: :unprocessable_entity
        end
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

  # An RSVP is only reachable through an event the user may see: without this
  # an outsider could answer a private society's event and read its attendee
  # list from the turbo-stream response.
  def set_event
    @event = Event.find(params[:event_id])
    authorize @event, :show?
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

  # Only ever the signed-in user's own RSVP; there is nothing to change or
  # cancel if they never answered, so that is a 404 rather than a nil policy.
  def set_rsvp
    @rsvp = @event.event_rsvps.find_by(user: current_user)
    return if @rsvp

    Rails.logger.warn "Event #{@event.id}: RSVP #{action_name} by user #{current_user.id} refused: no RSVP to #{action_name}"
    raise ActiveRecord::RecordNotFound
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
