class EventRsvpsController < ApplicationController
  before_action :set_event
  before_action :set_rsvp, only: [:update, :destroy]

  def create
    @rsvp = @event.event_rsvps.build(user: current_user, status: 'confirmed')
    authorize @rsvp, :create?

    if @rsvp.save
      redirect_to @event, notice: 'Successfully RSVPed to the event!'
    else
      redirect_to @event, alert: 'Unable to RSVP to the event.'
    end
  end

  def update
    authorize @rsvp

    if @rsvp.update(rsvp_params)
      redirect_to @event, notice: 'RSVP was successfully updated.'
    else
      redirect_to @event, alert: 'Unable to update RSVP.'
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
end
