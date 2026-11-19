# One-click "stop event emails" from the footer of event emails (B15, I23).
# The signed token names one member, one event (for context) and one purpose,
# so it cannot be used for anything else, and an RSVP token cannot be used
# here. No session is needed: the mute is the same reversible preference as
# the account-page checkbox (User#event_emails), and only the token's own
# member is affected.
#
# GET shows a one-button confirm page (mail scanners follow links); POST
# applies the mute. The POST also serves RFC 8058 one-click clients
# (List-Unsubscribe-Post), which send no CSRF token.
class EventMutesController < ApplicationController
  PURPOSE = "mute_event_emails".freeze

  skip_forgery_protection only: :create

  def show
    @user, @event = load_link
    return if performed?

    @token = params[:token]
    Rails.logger.info "Event mute confirm page shown for user #{@user.id}, event #{@event.id}"
  end

  def create
    user, event = load_link
    return if performed?

    if user.event_emails?
      user.update_columns(event_emails: false, updated_at: Time.current)
      Rails.logger.info "Event emails muted for user #{user.id} via one-click link (event #{event.id})"
    else
      Rails.logger.info "Event mute for user #{user.id} (event #{event.id}): already muted, no change"
    end
    @user = user
    render :create
  end

  def self.verifier
    Rails.application.message_verifier(:event_mute)
  end

  def self.token_for(user, event)
    verifier.generate({ "user_id" => user.id, "event_id" => event.id, "purpose" => PURPOSE }, expires_in: 180.days)
  end

  private

  def load_link
    data = self.class.verifier.verify(params[:token].to_s)
    raise ActiveSupport::MessageVerifier::InvalidSignature unless data.is_a?(Hash) && data["purpose"] == PURPOSE

    [ User.find(data["user_id"]), Event.find(data["event_id"]) ]
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
    # Expired/forged token or a since-deleted event/user; never log the token.
    Rails.logger.warn "Event mute link rejected: #{e.class}"
    redirect_to root_path, alert: "That link is no longer valid."
    nil
  end
end
