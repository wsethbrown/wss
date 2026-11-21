require "test_helper"

# B15 (I3, I23): event emails show the event's own zone and carry a
# one-click unsubscribe.
class EventMailerTest < ActionMailer::TestCase
  setup do
    @society = societies(:whiskey_lovers)
    @organizer = users(:john)
    @member = users(:jane)
    @start = Time.utc(2027, 1, 15, 0, 30) # 7:30 PM EST on Jan 14
    @event = Event.create!(society: @society, organizer: @organizer, title: "Zone Night", description: "x",
                           location: "The den", start_time: @start, end_time: @start + 2.hours,
                           time_zone: "America/New_York")
  end

  def bodies(mail)
    [ mail.html_part.body.decoded, mail.text_part.body.decoded ]
  end

  test "created, updated and reminder emails show 7:30 PM EST in html and text" do
    [ EventMailer.event_created(@member, @event),
      EventMailer.event_updated(@member, @event, [ "time" ]),
      EventMailer.event_reminder(@member, @event) ].each do |mail|
      bodies(mail).each do |body|
        assert_includes body, "7:30 PM EST", "#{mail.subject}: #{body[0, 200]}"
        assert_not_includes body, "12:30 AM"
      end
    end
  end

  test "the rsvp email names the date in the event zone" do
    rsvp = EventRsvp.create!(user: @member, event: @event, status: "yes")
    mail = EventMailer.rsvp_received(@organizer, rsvp)
    bodies(mail).each { |b| assert_includes b, "Thursday, January 14" }
  end

  test "member-facing emails carry List-Unsubscribe headers and a body link" do
    [ EventMailer.event_created(@member, @event), EventMailer.event_reminder(@member, @event),
      EventMailer.event_updated(@member, @event, [ "time" ]) ].each do |mail|
      header = mail["List-Unsubscribe"].to_s
      assert_match %r{\A<https?://[^>]+/event_mute\?token=[^>]+>\z}, header
      assert_equal "List-Unsubscribe=One-Click", mail["List-Unsubscribe-Post"].to_s
      url = header[1..-2]
      bodies(mail).each { |b| assert_includes b, url }
    end
  end

  # The reminder goes out 48 hours ahead (finding 5), so it must not say
  # "Tomorrow", and what it says about changing an answer must be the rule.
  test "the reminder says when it is and states the real RSVP rule" do
    mail = EventMailer.event_reminder(@member, @event)
    assert_not_includes mail.subject, "Tomorrow"
    assert_includes mail.subject, "Thursday, January 14"
    bodies(mail).each do |body|
      assert_not_includes body, "Tomorrow"
      assert_not_includes body, "at any time"
      assert_includes body, "You can change your answer until the night starts. A new yes closes 24 hours before."
    end
    assert_not_includes EventMailer.event_created(@member, @event).html_part.body.decoded, "at any time"
  end
end
