require "test_helper"

class MailingListSubscriberTest < ActiveSupport::TestCase
  test "stores the email stripped and downcased" do
    row = MailingListSubscriber.create!(email: "  Reader@Example.COM ")
    assert_equal "reader@example.com", row.email
  end

  test "requires a valid, unique email" do
    assert_not MailingListSubscriber.new(email: "").valid?
    assert_not MailingListSubscriber.new(email: "not-an-email").valid?

    MailingListSubscriber.create!(email: "reader@example.com")
    duplicate = MailingListSubscriber.new(email: "READER@example.com")
    assert_not duplicate.valid?
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "keeps source short" do
    assert_not MailingListSubscriber.new(email: "reader@example.com", source: "x" * 31).valid?
  end

  test "active is confirmed and not unsubscribed" do
    waiting = MailingListSubscriber.create!(email: "waiting@example.com")
    active = MailingListSubscriber.create!(email: "active@example.com", confirmed_at: 1.day.ago)
    gone = MailingListSubscriber.create!(email: "gone@example.com", confirmed_at: 2.days.ago, unsubscribed_at: 1.day.ago)

    assert_equal [ active ], MailingListSubscriber.active.to_a
    assert_equal [ waiting ], MailingListSubscriber.awaiting_confirmation.to_a
    assert_equal [ gone ], MailingListSubscriber.unsubscribed.to_a
    assert active.active?
    assert_not waiting.active?
    assert_not gone.active?
  end
end
