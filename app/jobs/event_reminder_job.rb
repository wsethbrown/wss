# The 48-hours-before reminder (to yes and maybe answers), scheduled at event creation (and re-scheduled
# on time changes). The scheduled_start stamp makes stale jobs no-ops: when an
# event is rescheduled, the old job wakes, sees the stamp mismatch, and does
# nothing; the newly scheduled job carries the new stamp.
class EventReminderJob < ApplicationJob
  queue_as :default

  # 48 hours leaves a day of open yeses after it lands (Event::YES_CUTOFF), so
  # every button in it works when it arrives.
  LEAD_TIME = 48.hours

  def self.schedule(event)
    return if event.start_time.blank?

    run_at = event.start_time - LEAD_TIME
    if run_at <= Time.current # the send time has passed: they just heard about it
      Rails.logger.info "EventReminderJob: event #{event.id} starts within 48h; no reminder scheduled"
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

    attendees = event.event_rsvps.where(status: %w[yes maybe]).includes(:user).map(&:user).uniq
    recipients = attendees.select(&:event_emails?)
    Rails.logger.info "EventReminderJob: event #{event.id}: emailing #{recipients.size} of #{attendees.size} yes/maybe RSVPs (rest muted)"
    recipients.each do |user|
      sent = once("event_reminder:#{event.id}:#{scheduled_start}:#{user.id}") do
        EventMailer.event_reminder(user, event).deliver_later
      end
      Rails.logger.info "EventReminderJob: event #{event.id}: user #{user.id} already reminded; skipping duplicate" unless sent
    end
  end
end
