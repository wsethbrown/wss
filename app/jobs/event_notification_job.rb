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
    unless event
      Rails.logger.info "EventNotificationJob: event #{event_id} no longer exists; skipping"
      return
    end

    case kind.to_s
    when "created"
      members = event.society.society_memberships.where(status: "active").includes(:user).map(&:user)
      # In-app notifications go to every member; the event_emails mute only
      # silences EMAIL, the bell still rings.
      belled = 0
      members.uniq.each do |user|
        next if user.id == event.organizer_id

        belled += 1 if Notification.notify!(user: user, actor: event.organizer, notifiable: event, action: "event_created")
      end
      emailed = recipients(members, event) do |user|
        EventMailer.event_created(user, event).deliver_later
      end
      Rails.logger.info "EventNotificationJob: event #{event.id} created: notified #{belled} members in-app, emailed #{emailed} (rest muted)"
    when "updated"
      yes_users = event.event_rsvps.where(status: "yes").includes(:user).map(&:user)
      emailed = recipients(yes_users, event) do |user|
        EventMailer.event_updated(user, event, changed_fields).deliver_later
      end
      Rails.logger.info "EventNotificationJob: event #{event.id} updated (#{changed_fields.join(', ')}): emailed #{emailed} of #{yes_users.uniq.size} yes-RSVPs"
    end
  end

  private

  # Yields each eligible recipient; returns how many were yielded so the
  # caller can log the fan-out.
  def recipients(users, event)
    count = 0
    users.uniq.each do |user|
      next if user.id == event.organizer_id
      next unless user.event_emails?

      count += 1
      yield user
    end
    count
  end
end
