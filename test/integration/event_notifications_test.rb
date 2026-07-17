require "test_helper"

# Event notification emails (owner-approved, July 2026): created -> active
# members, RSVP (with note) -> organizer, time/location changes -> yes-RSVPs,
# 24h reminder -> yes-RSVPs. All respect the User#event_emails mute.
class EventNotificationsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  def setup
    @organizer = users(:john)
    @member = users(:jane)
    # Creating a society auto-enrolls the creator as an admin member.
    @society = Society.create!(name: "Notify Club", description: "x", creator: @organizer, is_private: false)
    SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
  end

  def build_event(start_time: 3.days.from_now)
    Event.create!(society: @society, organizer: @organizer, title: "Peat Night",
                  description: "x", location: "The den",
                  start_time: start_time, end_time: start_time + 3.hours)
  end

  # ---- event created --------------------------------------------------------
  test "creating an event notifies active members except the organizer" do
    event = build_event
    EventNotificationJob.perform_now(event.id, "created")
    assert_equal [@member.email], enqueued_mail_recipients("event_created")
  end

  test "muted members are skipped" do
    @member.update!(event_emails: false)
    event = build_event
    EventNotificationJob.perform_now(event.id, "created")
    assert_empty enqueued_mail_recipients("event_created")
  end

  test "the events controller enqueues announcement and reminder on create" do
    sign_in @organizer
    assert_enqueued_with(job: EventNotificationJob) do
      post society_events_path(@society), params: { event: {
        society_id: @society.id, title: "New Night", description: "x",
        location: "The den", start_time: 3.days.from_now, end_time: 3.days.from_now + 2.hours
      } }
    end
    assert_enqueued_jobs 1, only: EventReminderJob
  end

  # ---- rsvp -> organizer ----------------------------------------------------
  test "an RSVP with a note emails the organizer" do
    event = build_event
    sign_in @member
    assert_enqueued_emails 1 do
      post event_event_rsvps_path(event), params: { status: "yes", note: "Bringing the Ardbeg" }
    end
    assert_equal "Bringing the Ardbeg", event.event_rsvps.find_by(user: @member).note
  end

  test "the organizer's own RSVP does not email them" do
    event = build_event
    sign_in @organizer
    assert_no_enqueued_emails do
      post event_event_rsvps_path(event), params: { status: "yes" }
    end
  end

  test "a muted organizer is not emailed" do
    @organizer.update!(event_emails: false)
    event = build_event
    sign_in @member
    assert_no_enqueued_emails do
      post event_event_rsvps_path(event), params: { status: "yes" }
    end
  end

  # ---- event updated --------------------------------------------------------
  test "changing the location notifies yes-RSVPs" do
    event = build_event
    EventRsvp.create!(user: @member, event: event, status: "yes")
    sign_in @organizer
    assert_enqueued_with(job: EventNotificationJob, args: [event.id, "updated", ["location"]]) do
      patch society_event_path(@society, event), params: { event: { location: "New spot" } }
    end
  end

  test "an unrelated edit notifies nobody" do
    event = build_event
    sign_in @organizer
    assert_no_enqueued_jobs(only: EventNotificationJob) do
      patch society_event_path(@society, event), params: { event: { description: "richer copy" } }
    end
  end

  # ---- reminder -------------------------------------------------------------
  test "the reminder mails yes-RSVPs with the matching stamp" do
    event = build_event
    EventRsvp.create!(user: @member, event: event, status: "yes")
    EventRsvp.create!(user: users(:seth), event: event, status: "no")
    EventReminderJob.perform_now(event.id, event.start_time.to_i)
    assert_equal [@member.email], enqueued_mail_recipients("event_reminder")
  end

  test "a stale reminder stamp is a no-op" do
    event = build_event
    EventRsvp.create!(user: @member, event: event, status: "yes")
    EventReminderJob.perform_now(event.id, (event.start_time - 2.hours).to_i)
    assert_empty enqueued_mail_recipients("event_reminder")
  end

  test "no reminder is scheduled for events under 24 hours away" do
    event = build_event(start_time: 10.hours.from_now)
    assert_no_enqueued_jobs(only: EventReminderJob) do
      EventReminderJob.schedule(event)
    end
  end

  # ---- mailer content -------------------------------------------------------
  test "the rsvp email carries the guest note" do
    event = build_event
    rsvp = EventRsvp.create!(user: @member, event: event, status: "yes", note: "Bringing a bottle")
    mail = EventMailer.rsvp_received(@organizer, rsvp)
    assert_match "Bringing a bottle", mail.body.encoded
    assert_match @member.full_name, mail.subject
  end

  test "the account toggle persists" do
    sign_in @member
    patch "/account/profile", params: { user: { first_name: @member.first_name, event_emails: "0" } }
    assert_not @member.reload.event_emails?
  end


  private

  # Test env delivers mail to files, so ActionMailer::Base.deliveries stays
  # empty; recipients are asserted from the enqueued MailDeliveryJobs instead.
  def enqueued_mail_recipients(action)
    enqueued_jobs.filter_map do |j|
      next unless j[:job] == ActionMailer::MailDeliveryJob

      margs = ActiveJob::Arguments.deserialize(j[:args])
      next unless margs[1] == action.to_s

      margs[3][:args].first.email
    end
  end
end
