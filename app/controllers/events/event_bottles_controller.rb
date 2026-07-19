# Pour-list management: the organizer (or society admins) builds the night's
# lineup. Position is append-only here; reordering is a later nicety.
class Events::EventBottlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def create
    authorize @event, :manage_pours?
    bottle = Bottle.find_by(id: params.dig(:event_bottle, :bottle_id))
    if bottle.nil?
      redirect_to event_page, alert: "Pick a bottle from the search results first."
      return
    end

    pour = @event.event_bottles.new(
      bottle: bottle,
      label: params.dig(:event_bottle, :label),
      # The host's own words for tonight, prefilled in the form from the
      # bottle. Stored on the pour, never written back to the bottle.
      notes: params.dig(:event_bottle, :notes),
      position: (@event.event_bottles.maximum(:position) || 0) + 1
    )

    if pour.save
      redirect_to event_page, notice: "#{bottle.name} is on the pour list."
    else
      redirect_to event_page, alert: pour.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @event, :manage_pours?
    pour = @event.event_bottles.find(params[:id])

    if pour.update(pour_params)
      Rails.logger.info "Event pour #{pour.id} (event #{@event.id}, bottle #{pour.bottle_id}) notes edited by user #{current_user.id}"
      redirect_to event_page, notice: "Notes updated."
    else
      Rails.logger.warn "Event pour #{pour.id} (event #{@event.id}) update refused for user #{current_user.id}: #{pour.errors.full_messages.to_sentence}"
      redirect_to event_page, alert: pour.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @event, :manage_pours?
    pour = @event.event_bottles.find(params[:id])

    if pour.destroy
      redirect_to event_page, notice: "Pour removed."
    else
      redirect_to event_page, alert: pour.errors.full_messages.to_sentence
    end
  end

  private

  # Only the host's own framing is editable here. bottle_id is not: repointing
  # a pour at a different bottle would silently reassign the night's reviews.
  def pour_params
    params.require(:event_bottle).permit(:notes, :label)
  end

  def set_event
    @event = Event.find(params[:event_id])
  end

  # The canonical event URL is the society-nested one.
  def event_page
    society_event_path(@event.society, @event)
  end
end
