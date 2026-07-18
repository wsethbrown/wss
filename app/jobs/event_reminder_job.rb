# The 24-hours-before reminder, scheduled at event creation (and re-scheduled
# on time changes). The scheduled_start stamp makes stale jobs no-ops: when an
# event is rescheduled, the old job wakes, sees the stamp mismatch, and does
# nothing; the newly scheduled job carries the new stamp.
class EventReminderJob < ApplicationJob
  queue_as :default

  def self.schedule(event)
    return if event.start_time.blank?

    run_at = event.start_time - 24.hours
    if run_at <= Time.current # under 24h away: no reminder, they just heard about it
      Rails.logger.info "EventReminderJob: event #{event.id} starts within 24h; no reminder scheduled"
      return
    end

    Rails.logger.info "EventReminderJob: event #{event.id} reminder scheduled for #{run_at}"
    set(wait_until: run_at).perform_later(event.id, event.start_time.to_i)
  end

  def perform(event_id, scheduled_start)
    event = Event.find_by(id: event_id)
    unless event
      Rails.logger.info "EventReminderJob: event #{event_id} no longer exists; skipping"
      return
    end
    unless event.start_time.to_i == scheduled_start # rescheduled: stale job
      Rails.logger.info "EventReminderJob: event #{event.id} was rescheduled; stale reminder skipped"
      return
    end
    if event.start_time <= Time.current
      Rails.logger.info "EventReminderJob: event #{event.id} already started; reminder skipped"
      return
    end

    attendees = event.event_rsvps.where(status: "yes").includes(:user).map(&:user).uniq
    recipients = attendees.select(&:event_emails?)
    Rails.logger.info "EventReminderJob: event #{event.id}: emailing #{recipients.size} of #{attendees.size} yes-RSVPs (rest muted)"
    recipients.each do |user|
      EventMailer.event_reminder(user, event).deliver_later
    end
  end
end
