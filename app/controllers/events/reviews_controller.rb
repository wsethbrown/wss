# Creating a review in the context of an event pour. The event tie is set
# here and only here; the model's gates (pour membership, reveal, RSVP)
# decide whether it saves. Edits go through the shared ReviewsController
# and can never move a review to a different event.
class Events::ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event_and_bottle
  after_action :verify_authorized

  def new
    @review = Review.new(event: @event, bottle: @bottle)
  end

  def create
    @review = Review.new(review_params)
    @review.user = current_user
    @review.event = @event
    @review.bottle = @bottle

    if @review.save
      redirect_to society_event_path(@event.society, @event), notice: "Your pour is on the record."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  # The form names the event and its society, so it is only for people who
  # may see the event (a private society's members). The model's own gates
  # still decide whether a review saves.
  def set_event_and_bottle
    @event = Event.find(params[:event_id])
    authorize @event, :show?
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes, :price_paid, flavor_wheel: Review::DESCRIPTOR_LEXICON.keys, images: [])
  end
end
