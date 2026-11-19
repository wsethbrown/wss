require "test_helper"

# I25: a deploy mid-fan-out (or a Solid Queue retry) re-runs the job. Running it
# twice must still send one notification and one email per member.
class EventFanoutIdempotencyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @store = ActiveSupport::Cache::MemoryStore.new
    Rails.stubs(:cache).returns(@store)
    @organizer = users(:john)
    @member = users(:jane)
    @society = Society.create!(name: "Twice Club", description: "x", creator: @organizer, is_private: false)
    SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
    @event = Event.create!(society: @society, organizer: @organizer, title: "Peat Night", description: "x",
                           location: "The den", start_time: 3.days.from_now, end_time: 3.days.from_now + 3.hours)
    EventRsvp.create!(event: @event, user: @member, status: "yes")
    clear_enqueued_jobs
  end

  def mail_jobs = enqueued_jobs.select { |j| j[:job] == ActionMailer::MailDeliveryJob }

  test "running the created fan-out twice sends one notification and one email per member" do
    assert_difference -> { Notification.where(user: @member, action: "event_created").count }, 1 do
      2.times { EventNotificationJob.perform_now(@event.id, "created") }
    end
    assert_equal 1, mail_jobs.size
  end

  test "running the updated fan-out twice sends one email per yes-RSVP" do
    2.times { EventNotificationJob.perform_now(@event.id, "updated", [ "location" ]) }
    assert_equal 1, mail_jobs.size
  end

  test "a later, different update still emails" do
    EventNotificationJob.perform_now(@event.id, "updated", [ "location" ])
    @event.update_columns(updated_at: 1.minute.from_now)
    EventNotificationJob.perform_now(@event.id, "updated", [ "start_time" ])
    assert_equal 2, mail_jobs.size
  end

  test "running the reminder twice sends one email per yes-RSVP" do
    start = @event.start_time.to_i
    2.times { EventReminderJob.perform_now(@event.id, start) }
    assert_equal 1, mail_jobs.size
  end

  test "a failed enqueue releases the claim so a retry can send" do
    EventMailer.stubs(:event_reminder).raises(RuntimeError, "boom").then.returns(stub(deliver_later: true))
    assert_raises(RuntimeError) { EventReminderJob.perform_now(@event.id, @event.start_time.to_i) }
    assert_nothing_raised { EventReminderJob.perform_now(@event.id, @event.start_time.to_i) }
  end
end
