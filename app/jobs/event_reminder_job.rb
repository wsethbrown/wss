# The 24-hours-before reminder, scheduled at event creation (and re-scheduled
# on time changes). The scheduled_start stamp makes stale jobs no-ops: when an
# event is rescheduled, the old job wakes, sees the stamp mismatch, and does
# nothing; the newly scheduled job carries the new stamp.
class EventReminderJob < ApplicationJob
  queue_as :default

  def self.schedule(event)
    return if event.start_time.blank?

    run_at = event.start_time - 24.hours
    return if run_at <= Time.current # under 24h away: no reminder, they just heard about it

    set(wait_until: run_at).perform_later(event.id, event.start_time.to_i)
  end

  def perform(event_id, scheduled_start)
    event = Event.find_by(id: event_id)
    return unless event
    return unless event.start_time.to_i == scheduled_start # rescheduled: stale job
    return if event.start_time <= Time.current

    event.event_rsvps.where(status: "yes").includes(:user).map(&:user).uniq.each do |user|
      next unless user.event_emails?

      EventMailer.event_reminder(user, event).deliver_later
    end
  end
end
