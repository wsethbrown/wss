# Fans out event emails to the right audience. Runs in Solid Queue so a big
# society never blocks a request; each recipient becomes their own mailer job.
#
#   kind "created": every ACTIVE society member except the organizer
#   kind "updated": everyone RSVP'd yes, except the organizer (they made the change)
#
# Every recipient is filtered on User#event_emails (the account-page mute).
class EventNotificationJob < ApplicationJob
  queue_as :default

  def perform(event_id, kind, changed_fields = [])
    event = Event.find_by(id: event_id)
    return unless event

    case kind.to_s
    when "created"
      recipients(event.society.society_memberships.where(status: "active").includes(:user).map(&:user), event) do |user|
        EventMailer.event_created(user, event).deliver_later
      end
    when "updated"
      recipients(event.event_rsvps.where(status: "yes").includes(:user).map(&:user), event) do |user|
        EventMailer.event_updated(user, event, changed_fields).deliver_later
      end
    end
  end

  private

  def recipients(users, event)
    users.uniq.each do |user|
      next if user.id == event.organizer_id
      next unless user.event_emails?

      yield user
    end
  end
end
