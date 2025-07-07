class EventsController < ApplicationController
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  def index
    @events = Event.includes(:society, :organizer, :event_rsvps)
                   .search(params[:search])
                   .by_society(params[:society_id])
                   .order(:start_time)
                   .page(params[:page])

    @events = @events.upcoming if params[:filter] == 'upcoming'
    @events = @events.past if params[:filter] == 'past'
  end

  def show
    @rsvps = @event.event_rsvps.includes(:user)
    @confirmed_attendees = @event.confirmed_attendees
    @pending_rsvps = @event.pending_rsvps
  end

  def new
    @event = Event.new
    @event.society_id = params[:society_id] if params[:society_id]
    authorize @event
  end

  def create
    @event = Event.new(event_params)
    @event.organizer = current_user
    authorize @event

    if @event.save
      redirect_to @event, notice: 'Event was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @event
  end

  def update
    authorize @event

    if @event.update(event_params)
      redirect_to @event, notice: 'Event was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @event

    @event.destroy
    redirect_to events_url, notice: 'Event was successfully deleted.'
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :description, :location, :start_time, :end_time, :society_id)
  end
end
