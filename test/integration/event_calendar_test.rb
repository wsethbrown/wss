require "test_helper"

# Add to calendar (finding 6): one event's .ics behind the same permission as
# the event page, a Google Calendar link, and the .ics on the created/updated emails.
class EventCalendarTest < ActionDispatch::IntegrationTest
  setup do
    @public_event = events(:mystery_flight)    # single_malt, public
    @private_event = events(:allocated_night)  # bourbon_club, private
  end

  def ics_path(event) = society_event_path(event.society, event, format: :ics)

  test "anyone who can see a public event can download its .ics" do
    get ics_path(@public_event)
    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_includes response.body, "UID:event-#{@public_event.id}@whiskeysharesociety.com"
    assert_includes response.body.gsub("\r\n ", ""), society_event_url(@public_event.society, @public_event)
  end

  test "a private society's .ics is refused to outsiders and served to members" do
    get ics_path(@private_event)
    assert_not_includes response.body, "BEGIN:VCALENDAR"

    sign_in users(:seth) # not a member of bourbon_club
    get ics_path(@private_event)
    assert_not_includes response.body, "BEGIN:VCALENDAR"
    assert_not_includes response.body, @private_event.title

    sign_in users(:jane) # its creator
    get ics_path(@private_event)
    assert_response :success
    assert_includes response.body, "BEGIN:VEVENT"
  end

  test "the event page offers the .ics and a Google Calendar link" do
    get society_event_path(@public_event.society, @public_event)
    assert_select "a[href='#{ics_path(@public_event)}']"
    google = css_select("a[href^='https://calendar.google.com/calendar/render']").first
    assert google, "Google Calendar link missing"
    query = Rack::Utils.parse_query(URI(google["href"]).query)
    assert_equal "TEMPLATE", query["action"]
    assert_equal @public_event.title, query["text"]
    assert_equal "#{EventIcs.utc(@public_event.start_time)}/#{EventIcs.utc(@public_event.end_time)}", query["dates"]
    assert_equal @public_event.location, query["location"]
  end

  test "the created and updated emails carry the .ics with the event's UID" do
    member = users(:seth)
    [ EventMailer.event_created(member, @public_event),
      EventMailer.event_updated(member, @public_event, [ "time" ]) ].each do |mail|
      ics = mail.attachments.find { |a| a.filename.end_with?(".ics") }
      assert ics, "#{mail.subject}: no .ics attached"
      assert_equal "text/calendar", ics.mime_type
      assert_includes ics.decoded, "UID:event-#{@public_event.id}@whiskeysharesociety.com"
      assert mail.html_part && mail.text_part, "the body parts survive the attachment"
    end
  end
end
