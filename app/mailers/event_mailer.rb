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
    mail(to: user.email, subject: "New tasting night: #{event.title} at #{@society.name}")
  end

  def rsvp_received(organizer, rsvp)
    @organizer = organizer
    @rsvp = rsvp
    @event = rsvp.event
    @guest = rsvp.user
    mail(to: organizer.email, subject: "#{@guest.full_name} RSVP'd #{rsvp.status} to #{@event.title}")
  end

  def event_updated(user, event, changed_fields)
    @user = user
    @event = event
    @changed_fields = changed_fields
    mail(to: user.email, subject: "Update to #{event.title}")
  end

  def event_reminder(user, event)
    @user = user
    @event = event
    mail(to: user.email, subject: "Tomorrow: #{event.title}")
  end
end
