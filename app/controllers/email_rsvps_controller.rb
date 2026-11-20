# One-click RSVP from event emails (the calendar-invite pattern). The signed
# token IS the authorization: it names one user and one event, is minted only
# into that user's own email, and expires. No session is created.
#
# Mail scanners and link previewers follow GET links, so the emailed link
# (GET, #show) only renders a one-button confirmation page; the button POSTs
# to #create, which records the answer (B8, S12). Both re-check the RSVP
# policy for the token's user, so a removed member's old link stops working.
class EmailRsvpsController < ApplicationController
  VALID_STATUSES = %w[yes maybe no].freeze
  # The emailed buttons' own labels, reused on the confirm page.
  BUTTON_LABELS = { "yes" => "RSVP yes", "maybe" => "Maybe", "no" => "Can't make it" }.freeze

  def show
    @event, @user, @status = load_link
    return if performed?
    return unless allowed?(@event, @user, @status)

    @token = params[:token]
    @button_label = BUTTON_LABELS.fetch(@status)
    Rails.logger.info "Email RSVP confirm page shown for event #{@event.id}, user #{@user.id} (#{@status})"
  end

  def create
    event, user, status = load_link
    return if performed?
    return unless allowed?(event, user, status)

    rsvp = event.event_rsvps.find_or_initialize_by(user: user)
    rsvp.status = status

    if rsvp.save
      Rails.logger.info "Email RSVP recorded: user #{user.id} marked #{status} for event #{event.id}"
      # Organizer + event host hear about email RSVPs, same as on-site ones.
      [ event.organizer, event.host ].compact.uniq.each do |recipient|
        next if recipient.id == user.id
        unless recipient.event_emails?
          Rails.logger.info "Event #{event.id}: RSVP notification to user #{recipient.id} skipped (event emails muted)"
          next
        end

        Rails.logger.info "Event #{event.id}: RSVP notification to user #{recipient.id} enqueued"
        EventMailer.rsvp_received(recipient, rsvp).deliver_later
      end
      redirect_to society_event_path(event.society, event),
                  notice: "You're marked #{status} for #{event.title}."
    else
      Rails.logger.error "Email RSVP save failed for user #{user.id}, event #{event.id}: #{rsvp.errors.full_messages.to_sentence}"
      redirect_to society_event_path(event.society, event),
                  alert: rsvp.errors.full_messages.to_sentence
    end
  end

  # Tokens are scoped per user+event and die with the event window.
  def self.verifier
    Rails.application.message_verifier(:email_rsvp)
  end

  def self.token_for(user, event)
    verifier.generate({ "user_id" => user.id, "event_id" => event.id }, expires_in: 60.days)
  end

  private

  # [event, user, status] from the signed token, or a redirect (performed?).
  def load_link
    data = self.class.verifier.verify(params[:token])
    event = Event.find(data["event_id"])
    user = User.find(data["user_id"])
    status = VALID_STATUSES.include?(params[:status]) ? params[:status] : nil

    unless status
      Rails.logger.warn "Email RSVP rejected for event #{event.id}, user #{user.id}: unknown status #{params[:status].to_s.truncate(20).inspect}"
      redirect_to society_event_path(event.society, event), alert: "That RSVP link is not valid."
      return
    end

    [ event, user, status ]
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
    # Expired/forged token or a since-deleted event/user; never log the token.
    Rails.logger.warn "Email RSVP link rejected: #{e.class}"
    redirect_to root_path, alert: "That RSVP link is no longer valid."
    nil
  end

  # The same rules as the on-site RSVP control: a first answer needs
  # EventPolicy#rsvp? (eligible, window open); changing an answer needs
  # EventRsvpPolicy#update? (still eligible, window open). The link outlives
  # membership, so a removed member of a private society is refused here.
  def allowed?(event, user, status)
    unless event.rsvp_eligible?(user)
      Rails.logger.warn "Email RSVP rejected for event #{event.id}, user #{user.id}: no longer eligible (society #{event.society_id})"
      redirect_to root_path, alert: "That RSVP link is no longer valid."
      return false
    end

    existing = event.event_rsvps.find_by(user: user)
    permitted = existing ? EventRsvpPolicy.new(user, existing).update? : EventPolicy.new(user, event).rsvp?
    unless permitted
      Rails.logger.warn "Email RSVP rejected for event #{event.id}, user #{user.id}: RSVP window closed (#{existing ? 'change' : 'new answer'})"
      redirect_to society_event_path(event.society, event), alert: "RSVPs closed when the night started"
      return false
    end

    # A new yes closes 24 hours out (Event#answer_allowed?); say so before the
    # confirm page offers a button that cannot work.
    unless event.answer_allowed?(status, existing&.status)
      Rails.logger.warn "Email RSVP rejected for event #{event.id}, user #{user.id}: new yes inside the last 24 hours"
      redirect_to society_event_path(event.society, event), alert: "New yes answers close 24 hours before the event"
      return false
    end
    true
  end
end
