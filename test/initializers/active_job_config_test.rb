require "test_helper"

# I1 + I6: mail jobs must not log their arguments (they carry raw tokens), and
# transient delivery failures must be retried while permanent ones are not.
class ActiveJobConfigTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  class ProbeMailer < ApplicationMailer
    cattr_accessor :error
    def probe
      raise self.class.error if self.class.error
      mail(to: "a@example.com", subject: "x", body: "x")
    end
  end

  test "mail delivery jobs do not log their arguments" do
    assert_equal false, ActionMailer::MailDeliveryJob.log_arguments
  end

  test "enqueueing a magic-link style mail writes no token to the log" do
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    ActiveJob::Base.logger.then do |original|
      ActiveJob::Base.logger = logger
      begin
        ProbeMailer.error = nil
        ActionMailer::MailDeliveryJob.perform_later("ActiveJobConfigTest::ProbeMailer", "probe", "deliver_now", args: [ "SECRET-RAW-TOKEN-123" ])
      ensure
        ActiveJob::Base.logger = original
      end
    end
    assert_not_includes io.string, "SECRET-RAW-TOKEN-123"
  end

  test "a transient network error is retried" do
    ProbeMailer.error = Net::OpenTimeout
    job = ActionMailer::MailDeliveryJob.new("ActiveJobConfigTest::ProbeMailer", "probe", "deliver_now", args: [])
    assert_nothing_raised { job.perform_now }
    assert_equal 1, enqueued_jobs.size, "the failed delivery should be re-enqueued for retry"
  ensure
    ProbeMailer.error = nil
  end

  test "a permanent SMTP error is not retried" do
    ProbeMailer.error = Net::SMTPFatalError.new("550 no such user")
    job = ActionMailer::MailDeliveryJob.new("ActiveJobConfigTest::ProbeMailer", "probe", "deliver_now", args: [])
    assert_raises(Net::SMTPFatalError) { job.perform_now }
    assert_empty enqueued_jobs
  ensure
    ProbeMailer.error = nil
  end
end
