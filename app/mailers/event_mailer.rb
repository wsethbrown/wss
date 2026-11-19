# Event notification emails (owner-approved design, July 2026):
#   event_created  -> society members when a new event is posted
#   rsvp_received  -> the organizer when someone responds (note included)
#   event_updated  -> yes-RSVPs when time or location changes
#   event_reminder -> yes-RSVPs 24 hours before start
# Every recipient is filtered on User#event_emails (the account-page mute)
# by the enqueuing jobs; templates keep to the magic-link email's plain style.
class EventMailer < ApplicationMailer
  helper :application

  def event_created(user, event)
    @user = user
    @event = event
    @society = event.society
    @rsvp_urls = rsvp_urls(user, event)
    mail_with_unsubscribe(user, event, subject: "New tasting night: #{event.title} at #{@society.name}")
  end

  def rsvp_received(organizer, rsvp)
    @organizer = organizer
    @rsvp = rsvp
    @event = rsvp.event
    @guest = rsvp.user
    mail_with_unsubscribe(organizer, @event, subject: "#{@guest.full_name} RSVP'd #{rsvp.status} to #{@event.title}")
  end

  def event_updated(user, event, changed_fields)
    @user = user
    @event = event
    @changed_fields = changed_fields
    mail_with_unsubscribe(user, event, subject: "Update to #{event.title}")
  end

  def event_reminder(user, event)
    @user = user
    @event = event
    @rsvp_urls = rsvp_urls(user, event)
    mail_with_unsubscribe(user, event, subject: "Tomorrow: #{event.title}")
  end

  private

  # Every event email is mutable, so each carries a signed one-click mute:
  # the List-Unsubscribe headers (RFC 8058) for mail clients, and @mute_url
  # for the link in the body (see EventMutesController).
  def mail_with_unsubscribe(user, event, subject:)
    @mute_url = event_mute_url(token: EventMutesController.token_for(user, event))
    headers["List-Unsubscribe"] = "<#{@mute_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    mail(to: user.email, subject: subject)
  end

  # One-click RSVP links, tokened per recipient (see EmailRsvpsController).
  def rsvp_urls(user, event)
    token = EmailRsvpsController.token_for(user, event)
    %w[yes maybe no].index_with { |s| email_rsvp_url(status: s, token: token) }
  end
end
