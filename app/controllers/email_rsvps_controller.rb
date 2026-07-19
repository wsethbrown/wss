# One-click RSVP from event emails (the calendar-invite pattern). The signed
# token IS the authorization: it names one user and one event, is minted only
# into that user's own email, and expires. No session is created; the person
# lands on the event page with their response recorded.
class EmailRsvpsController < ApplicationController
  VALID_STATUSES = %w[yes maybe no].freeze

  def create
    data = self.class.verifier.verify(params[:token])
    event = Event.find(data["event_id"])
    user = User.find(data["user_id"])
    status = VALID_STATUSES.include?(params[:status]) ? params[:status] : nil

    unless status
      Rails.logger.warn "Email RSVP rejected for event #{event.id}, user #{user.id}: unknown status #{params[:status].inspect}"
      return redirect_to society_event_path(event.society, event), alert: "That RSVP link is not valid."
    end

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
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
    # Expired/forged token or a since-deleted event/user; never log the token.
    Rails.logger.warn "Email RSVP link rejected: #{e.class}"
    redirect_to root_path, alert: "That RSVP link is no longer valid."
  end

  # Tokens are scoped per user+event and die with the event window.
  def self.verifier
    Rails.application.message_verifier(:email_rsvp)
  end

  def self.token_for(user, event)
    verifier.generate({ "user_id" => user.id, "event_id" => event.id }, expires_in: 60.days)
  end
end
