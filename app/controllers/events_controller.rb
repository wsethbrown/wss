class EventsController < ApplicationController
  before_action :set_event, only: [ :show, :edit, :update, :destroy, :assign_host, :assign_deck,
                                   :deck_options, :host_options, :mention_options ]

  def index
    @events = policy_scope(Event).includes(:society, :organizer, :event_rsvps)
                   .search(params[:search])
                   .by_society(params[:society_id])
                   .order(:start_time)
                   .page(params[:page])

    @events = @events.upcoming if params[:filter] == "upcoming"
    @events = @events.past if params[:filter] == "past"
  end

  def show
    authorize @event
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
    resolve_host_query
    # A deck can only be attached by someone entitled to offer it; anything
    # else silently drops (decks are optional, never a hard failure). Checked
    # against ownership directly, NOT deck_options_for — that helper always
    # allows the event's current deck, which here is the one being smuggled.
    if @event.presentation_id.present?
      offerable_ids = [ @event.society&.creator_id, current_user.id, @event.host_id ].compact.uniq
      unless Presentation.published.exists?(id: @event.presentation_id, author_id: offerable_ids)
        Rails.logger.warn "Event create by user #{current_user.id}: deck #{@event.presentation_id} dropped, not offerable for society #{@event.society_id}"
        @event.presentation_id = nil
      end
    end

    # Convert times from browser timezone to UTC for storage
    if browser_timezone.present?
      Time.use_zone(browser_timezone) do
        @event.start_time = Time.zone.parse(params[:event][:start_time]) if params[:event][:start_time].present?
        @event.end_time = Time.zone.parse(params[:event][:end_time]) if params[:event][:end_time].present?
      end
    end

    authorize @event

    if @event.save
      # Announce to active members and schedule the 24h reminder.
      Rails.logger.info "Event #{@event.id} created in society #{@event.society_id} by user #{current_user.id}; member notifications enqueued"
      EventNotificationJob.perform_later(@event.id, "created")
      EventReminderJob.schedule(@event)
      redirect_to @event, notice: "Event was successfully created."
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
      # Time or location changes notify yes-RSVPs; a time change also
      # re-schedules the 24h reminder (the old job no-ops on its stale stamp).
      changed = []
      changed << "time" if @event.saved_change_to_start_time? || @event.saved_change_to_end_time?
      changed << "location" if @event.saved_change_to_location?
      if changed.any?
        Rails.logger.info "Event #{@event.id} updated (#{changed.join(', ')}) by user #{current_user.id}; notifying yes-RSVPs"
        EventNotificationJob.perform_later(@event.id, "updated", changed)
        EventReminderJob.schedule(@event) if changed.include?("time")
      end
      redirect_to @event, notice: "Event was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Set (or clear) the deck the night runs. Managers + the host; the deck
  # must be published and owned by the society creator, the organizer, or
  # the host, or blank to clear (decks are optional on events, owner rule).
  def assign_deck
    @society = @event.society
    authorize @event, :manage_deck?

    if params[:presentation_id].blank?
      @event.update!(presentation: nil)
      Rails.logger.info "Event #{@event.id}: deck cleared by user #{current_user.id}"
      redirect_to society_event_path(@society, @event), notice: "Deck removed from this event."
    else
      deck = deck_options_for(@event).find { |p| p.id == params[:presentation_id].to_i }
      if deck
        @event.update!(presentation: deck)
        Rails.logger.info "Event #{@event.id}: deck set to presentation #{deck.id} by user #{current_user.id}"
        redirect_to society_event_path(@society, @event), notice: "This night runs #{deck.title}."
      else
        redirect_to society_event_path(@society, @event), alert: "That deck isn't available for this event."
      end
    end
  end

  # JSON for the deck and host autocomplete fields on the event page.
  #
  # Authorized and scoped EXACTLY like the assignment actions they feed. These
  # hand back deck titles and member names, so a looser scope here would leak
  # precisely what assign_deck/assign_host refuse to accept: a search endpoint
  # is a read of the same data, not a lesser thing.
  def deck_options
    authorize @event, :manage_deck?
    render json: autocomplete_matches(deck_options_for(@event), params[:q], &:title)
  end

  # Who can be tagged in Table talk. Gated on comment?, NOT update?: anyone
  # who can join the conversation can tag someone in it, and gating it tighter
  # would leave most commenters unable to autocomplete the names they can
  # already read on the page.
  def mention_options
    authorize @event, :comment?

    query = params[:q].to_s.strip.downcase
    taggable = Mentions.candidates_for(@event).select { |user| user.handle.present? }
    matches = taggable.select do |user|
      query.blank? || user.handle.downcase.start_with?(query) || user.full_name.downcase.include?(query)
    end

    # A handle shared by two members can't be tagged unambiguously, so it is
    # not offered: suggesting it would produce a tag that renders as plain
    # text and notifies nobody (see Mentions).
    ambiguous = taggable.group_by { |user| user.handle.downcase }.select { |_, v| v.size > 1 }.keys
    matches.reject! { |user| ambiguous.include?(user.handle.downcase) }

    render json: matches.sort_by { |user| user.handle.downcase }
                        .first(AUTOCOMPLETE_LIMIT)
                        .map { |user| { id: user.id, handle: user.handle, name: user.full_name } }
  end

  def host_options
    authorize @event, :update?
    members = @event.society.society_memberships.where(status: "active")
                    .includes(:user).map(&:user).uniq
    render json: autocomplete_matches(members, params[:q], &:full_name)
  end

  # Hand the night to a member. The host must be an active member of the
  # society (or blank to clear); assignment rights = event update rights.
  def assign_host
    @society = @event.society
    authorize @event, :update?

    guest_name = params[:host_name].to_s.strip

    if params[:host_id].present?
      membership = @society.society_memberships.find_by(user_id: params[:host_id], status: "active")
      if membership
        # A member host wins over any leftover guest name (see Event).
        @event.update!(host: membership.user, host_name: nil)
        Rails.logger.info "Event #{@event.id}: host set to user #{membership.user_id} by user #{current_user.id}"
        redirect_to society_event_path(@society, @event), notice: "#{membership.user.full_name} is now hosting this event."
      else
        Rails.logger.warn "Event #{@event.id}: host assignment rejected: user #{params[:host_id]} is not an active member of society #{@society.id}"
        redirect_to society_event_path(@society, @event), alert: "The host must be an active member of this society."
      end
    elsif guest_name.present?
      # Nobody matched, so this is a guest presenter: someone running the night
      # who isn't a member. Same rule the create form already applies
      # (resolve_host_field), so the two ways of setting a host agree.
      @event.update!(host: nil, host_name: guest_name)
      Rails.logger.info "Event #{@event.id}: host set to guest presenter name by user #{current_user.id}"
      redirect_to society_event_path(@society, @event), notice: "#{guest_name} is hosting this event as a guest presenter."
    else
      # Clear BOTH: leaving host_name behind would show a host the page says
      # was just removed.
      @event.update!(host: nil, host_name: nil)
      Rails.logger.info "Event #{@event.id}: host removed by user #{current_user.id}"
      redirect_to society_event_path(@society, @event), notice: "Host removed."
    end
  end

  def destroy
    authorize @event

    if @event.destroy
      redirect_to events_url, notice: "Event was successfully deleted."
    else
      redirect_to society_event_path(@event.society, @event), alert: @event.errors.full_messages.to_sentence
    end
  end

  private

  def set_event
    @event = Event.find(params[:id])
  end

  # The creation form's host field is one input: an active-member name match
  # becomes the real host (host powers included); anything else is kept as
  # the guest presenter's name.
  def resolve_host_query
    query = params.dig(:event, :host_query).to_s.strip
    return if query.blank?

    member = @society&.society_memberships&.where(status: "active")&.includes(:user)
                     &.map(&:user)&.find { |u| u.full_name.strip.casecmp?(query) }
    if member
      Rails.logger.info "Event create by user #{current_user.id}: host field matched member #{member.id}"
      @event.host = member
    else
      Rails.logger.info "Event create by user #{current_user.id}: host field kept as a guest presenter name (no member match)"
      @event.host_name = query
    end
  end

  # Shared shape for the autocomplete endpoints: [{ id:, label: }], filtered
  # case-insensitively and capped so a huge society can't return a wall of
  # names. An empty query returns the first few, so focusing the field shows
  # what's available rather than an empty box.
  AUTOCOMPLETE_LIMIT = 10

  def autocomplete_matches(records, query, &label)
    query = query.to_s.strip.downcase
    matches = records.select { |record| query.blank? || label.call(record).to_s.downcase.include?(query) }
    matches.sort_by { |record| label.call(record).to_s.downcase }
           .first(AUTOCOMPLETE_LIMIT)
           .map { |record| { id: record.id, label: label.call(record) } }
  end

  # Decks offerable on an event: published, owned by the society creator,
  # the organizer, or the host. The current deck stays selectable.
  def deck_options_for(event)
    owner_ids = [ event.society.creator_id, event.organizer_id, event.host_id ].compact.uniq
    options = Presentation.published.where(author_id: owner_ids).to_a
    options |= [ event.presentation ] if event.presentation
    options
  end
  helper_method :deck_options_for

  def event_params
    # society_id is permitted only on create (the nested form); update must not
    # re-home an event, that would re-attribute its reviews/board rows and
    # switch their veiling.
    permitted = [ :title, :description, :location, :start_time, :end_time, :pours_hidden_until_complete ]
    permitted.push(:society_id, :presentation_id) if action_name == "create" || action_name == "new"
    params.require(:event).permit(*permitted)
  end
end
