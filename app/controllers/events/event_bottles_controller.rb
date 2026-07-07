# Pour-list management: the organizer (or society admins) builds the night's
# lineup. Position is append-only here; reordering is a later nicety.
class Events::EventBottlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def create
    authorize @event, :update?
    bottle = Bottle.find_by(id: params.dig(:event_bottle, :bottle_id))
    if bottle.nil?
      redirect_to event_page, alert: "Pick a bottle from the search results first."
      return
    end

    pour = @event.event_bottles.new(
      bottle: bottle,
      label: params.dig(:event_bottle, :label),
      position: (@event.event_bottles.maximum(:position) || 0) + 1
    )

    if pour.save
      redirect_to event_page, notice: "#{bottle.name} is on the pour list."
    else
      redirect_to event_page, alert: pour.errors.full_messages.to_sentence
    end
  end

  def destroy
    authorize @event, :update?
    pour = @event.event_bottles.find(params[:id])

    if pour.destroy
      redirect_to event_page, notice: "Pour removed."
    else
      redirect_to event_page, alert: pour.errors.full_messages.to_sentence
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  # The canonical event URL is the society-nested one.
  def event_page
    society_event_path(@event.society, @event)
  end
end
