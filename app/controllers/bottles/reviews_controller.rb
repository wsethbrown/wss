# Creating a review in the context of a bottle (solo tastings, Phase 1).
# Event-tagged creation arrives in Phase 2 via the event page.
class Bottles::ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bottle

  def new
    @review = @bottle.reviews.new
  end

  def create
    @review = @bottle.reviews.new(review_params)
    @review.user = current_user
    # Owner rule (July 2026): reviewing a bottle within a week of attending an
    # event where it was poured makes this an event review; otherwise it's a
    # plain solo review. Most recent qualifying night wins.
    @review.event = recent_attended_event_for(@bottle)

    if @review.save
      notice = if @review.event
        "Your tasting is on the record and linked to #{@review.event.title}."
      else
        "Your tasting is on the record."
      end
      redirect_to review_path(@review), notice: notice
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_bottle
    @bottle = Bottle.find_by!(slug: params[:bottle_id])
  end

  # The most recent event, ended within the last 7 days, that the reviewer
  # attended (RSVP yes) and that poured this bottle. Past events are always
  # revealed, so the secret-pours gate is satisfied by construction. Skips
  # events the user already reviewed this bottle at (one review per context).
  def recent_attended_event_for(bottle)
    Event.joins(:event_bottles, :event_rsvps)
         .where(event_bottles: { bottle_id: bottle.id })
         .where(event_rsvps: { user_id: current_user.id, status: "yes" })
         .where(end_time: 7.days.ago..Time.current)
         .order(end_time: :desc)
         .detect { |event| !current_user.reviews.exists?(bottle: bottle, event: event) }
  end

  def review_params
    params.require(:review).permit(:rating, :notes, :nose, :palate, :finish, :body_notes, :price_paid, flavor_wheel: Review::DESCRIPTOR_LEXICON.keys, images: [])
  end
end
