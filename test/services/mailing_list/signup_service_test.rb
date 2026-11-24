require "test_helper"

class MailingList::SignupServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  EMAIL = "curious.reader@example.com".freeze
  Service = MailingList::SignupService

  setup { clear_enqueued_jobs }

  def mail_jobs = enqueued_jobs.select { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }

  # The raw token only ever travels in the mail job's arguments.
  def last_raw_token = mail_jobs.last["arguments"].last["args"].last

  def capture_log
    io = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old
  end

  test "request creates an unconfirmed row, stores only a digest and enqueues the mail" do
    result = nil
    assert_difference -> { MailingListSubscriber.count }, 1 do
      result = Service.request("  Curious.Reader@Example.com ", source: "library")
    end

    assert result.success?
    row = MailingListSubscriber.find_by!(email: EMAIL)
    assert_equal "library", row.source
    assert_nil row.confirmed_at
    assert row.confirmation_sent_at.present?
    assert_equal 64, row.confirmation_token_digest.length
    assert_equal 1, mail_jobs.size
    assert_not_equal last_raw_token, row.confirmation_token_digest
    assert_equal Service.digest(last_raw_token), row.confirmation_token_digest
  end

  test "request rejects an invalid email and creates nothing" do
    assert_no_difference -> { MailingListSubscriber.count } do
      assert_not Service.request("not-an-email", source: "library").success?
    end
    assert_empty mail_jobs
  end

  test "an unknown source is not stored as typed" do
    Service.request(EMAIL, source: "<script>something long and strange</script>")
    assert_equal "other", MailingListSubscriber.find_by!(email: EMAIL).source
  end

  test "a repeat request before confirming refreshes the token and sends again" do
    Service.request(EMAIL, source: "library")
    first = last_raw_token
    assert_no_difference -> { MailingListSubscriber.count } do
      assert Service.request(EMAIL, source: "deck").success?
    end
    assert_equal 2, mail_jobs.size
    assert_not Service.confirm(first).confirmed?, "the older link is replaced"
    assert Service.confirm(last_raw_token).confirmed?
  end

  test "confirm marks the row confirmed once" do
    Service.request(EMAIL, source: "deck")
    raw = last_raw_token
    assert Service.pending?(raw)

    freeze_time do
      result = Service.confirm(raw)
      assert result.confirmed?
      assert_equal Time.current, result.subscriber.reload.confirmed_at
    end
    row = MailingListSubscriber.find_by!(email: EMAIL)
    assert row.active?

    stamp = row.confirmed_at
    again = Service.confirm(raw)
    assert again.already_confirmed?
    assert_equal stamp, row.reload.confirmed_at
  end

  test "confirm refuses a wrong, blank or expired token with no change" do
    Service.request(EMAIL, source: "deck")
    raw = last_raw_token
    row = MailingListSubscriber.find_by!(email: EMAIL)

    assert Service.confirm("wrong-token").invalid?
    assert Service.confirm("").invalid?
    assert Service.confirm(nil).invalid?

    travel Service::EXPIRY + 1.minute do
      assert_not Service.pending?(raw)
      assert Service.confirm(raw).invalid?
    end
    assert_nil row.reload.confirmed_at
  end

  test "a request for a confirmed, active address sends nothing and changes nothing" do
    Service.request(EMAIL, source: "library")
    Service.confirm(last_raw_token)
    row = MailingListSubscriber.find_by!(email: EMAIL)
    before = row.attributes
    clear_enqueued_jobs

    result = Service.request(EMAIL, source: "deck")

    assert result.success?
    assert_equal Service::REQUEST_MESSAGE, result.message
    assert_empty mail_jobs
    assert_equal before, row.reload.attributes
  end

  test "unsubscribe works with a signed token only, and is safe to repeat" do
    Service.request(EMAIL, source: "library")
    Service.confirm(last_raw_token)
    row = MailingListSubscriber.find_by!(email: EMAIL)
    token = Service.unsubscribe_token_for(row)

    assert_nil Service.unsubscribe("forged")
    assert_nil Service.unsubscribe(nil)
    assert_nil Service.unsubscribe(row.id.to_s)
    assert row.reload.active?

    assert_equal row, Service.subscriber_for_unsubscribe(token)
    assert row.reload.active?, "looking the link up changes nothing"

    assert_equal row, Service.unsubscribe(token)
    stamp = row.reload.unsubscribed_at
    assert stamp.present?
    assert_not row.active?
    assert_equal row, Service.unsubscribe(token)
    assert_equal stamp, row.reload.unsubscribed_at
  end

  test "a token signed for another purpose cannot unsubscribe" do
    row = MailingListSubscriber.create!(email: EMAIL, confirmed_at: Time.current)
    other = Service.verifier.generate({ "subscriber_id" => row.id, "purpose" => "something_else" })
    event_mute = EventMutesController.verifier.generate({ "subscriber_id" => row.id, "purpose" => Service::UNSUBSCRIBE_PURPOSE })

    assert_nil Service.unsubscribe(other)
    assert_nil Service.unsubscribe(event_mute)
    assert row.reload.active?
  end

  test "unsubscribing before confirming kills the confirm link" do
    Service.request(EMAIL, source: "library")
    raw = last_raw_token
    row = MailingListSubscriber.find_by!(email: EMAIL)
    Service.unsubscribe(Service.unsubscribe_token_for(row))

    assert Service.confirm(raw).invalid?
    assert_nil row.reload.confirmed_at
  end

  test "asking again after unsubscribing is a new request that needs confirming" do
    Service.request(EMAIL, source: "library")
    Service.confirm(last_raw_token)
    row = MailingListSubscriber.find_by!(email: EMAIL)
    Service.unsubscribe(Service.unsubscribe_token_for(row))
    clear_enqueued_jobs

    assert_no_difference -> { MailingListSubscriber.count } do
      assert Service.request(EMAIL, source: "deck").success?
    end

    row.reload
    assert_equal 1, mail_jobs.size
    assert_nil row.confirmed_at
    assert_nil row.unsubscribed_at
    assert_equal "deck", row.source
    assert_not row.active?
    assert Service.confirm(last_raw_token).confirmed?
    assert row.reload.active?
  end

  test "the service's log lines carry ids, never the address or a token" do
    row = nil
    raw = nil
    token = nil
    log = capture_log do
      Service.request(EMAIL, source: "library")
      raw = last_raw_token
      row = MailingListSubscriber.find_by!(email: EMAIL)
      Service.request(EMAIL, source: "library")
      raw = last_raw_token
      Service.confirm("wrong-token-value")
      Service.confirm(raw)
      Service.confirm(raw)
      Service.request(EMAIL, source: "deck")
      token = Service.unsubscribe_token_for(row)
      Service.unsubscribe("forged-token-value")
      Service.unsubscribe(token)
      Service.unsubscribe(token)
      Service.request("not-an-email", source: "deck")
    end

    assert_no_match(/curious|example\.com|not-an-email/i, log)
    [ raw, token, "wrong-token-value", "forged-token-value", row.confirmation_token_digest ].compact.each do |secret|
      assert_not_includes log, secret
    end
    assert_match(/Deck news request: subscriber #{row.id} \(new\), source library/, log)
    assert_match(/Deck news request: subscriber #{row.id} \(repeat\)/, log)
    assert_match(/Deck news confirmation email enqueued for subscriber #{row.id}/, log)
    assert_match(/Deck news confirmed: subscriber #{row.id}/, log)
    assert_match(/Deck news confirm refused: invalid or expired token/, log)
    assert_match(/subscriber #{row.id} already confirmed, nothing sent/, log)
    assert_match(/Deck news unsubscribed: subscriber #{row.id}/, log)
    assert_match(/Deck news unsubscribe refused/, log)
    assert_match(/Deck news request refused: invalid email/, log)
  end
end
