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
    @pours = @event.event_bottles.ordered.includes(:bottle)
    @pours_visible = @event.pours_visible_to?(current_user)
    @rsvps = @event.event_rsvps.includes(:user)
    @yes_attendees = @event.yes_attendees
    @maybe_attendees = @event.maybe_attendees
    @no_attendees = @event.no_attendees
    @pour_reviews = @event.reviews.includes(:user).recent_first.group_by(&:bottle_id)
    @my_event_reviews = user_signed_in? ? @event.reviews.where(user: current_user).index_by(&:bottle_id) : {}
    @can_review_pours = user_signed_in? && @event.pours_revealed? &&
                        @event.event_rsvps.exists?(user: current_user, status: "yes")
  end

  def new
    @society = Society.find(params[:society_id]) if params[:society_id]
    @event = Event.new
    @event.society_id = params[:society_id] if params[:society_id]
    authorize @event
  end

  def create
    @society = Society.find(event_params[:society_id]) if event_params[:society_id]
    @event = Event.new(event_params)
    @event.organizer = current_user

    # Convert times from browser timezone to UTC for storage
    if browser_timezone.present?
      Time.use_zone(browser_timezone) do
        @event.start_time = Time.zone.parse(params[:event][:start_time]) if params[:event][:start_time].present?
        @event.end_time = Time.zone.parse(params[:event][:end_time]) if params[:event][:end_time].present?
      end
    end

    authorize @event

    if @event.save
      redirect_to @event, notice: 'Event was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @society = @event.society
    authorize @event
  end

  def update
    @society = @event.society
    authorize @event

    # Convert times from browser timezone to UTC for storage
    updated_params = event_params
    if browser_timezone.present? && (params[:event][:start_time].present? || params[:event][:end_time].present?)
      Time.use_zone(browser_timezone) do
        updated_params = updated_params.merge(
          start_time: params[:event][:start_time].present? ? Time.zone.parse(params[:event][:start_time]) : @event.start_time,
          end_time: params[:event][:end_time].present? ? Time.zone.parse(params[:event][:end_time]) : @event.end_time
        )
      end
    end

    if @event.update(updated_params)
      redirect_to @event, notice: 'Event was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @event

    if @event.destroy
      redirect_to events_url, notice: 'Event was successfully deleted.'
    else
      redirect_to society_event_path(@event.society, @event), alert: @event.errors.full_messages.to_sentence
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  def event_params
    params.require(:event).permit(:title, :description, :location, :start_time, :end_time,
                                  :society_id, :pours_hidden_until_complete)
  end
end
