require "test_helper"

# A hand-written RFC 5545 VEVENT for one event (finding 6).
class EventIcsTest < ActiveSupport::TestCase
  setup do
    @start = Time.utc(2027, 1, 15, 0, 30) # 7:30 PM EST on Jan 14
    @event = Event.create!(society: societies(:whiskey_lovers), organizer: users(:john), title: "Zone Night",
                           description: "x", location: "The den", start_time: @start, end_time: @start + 2.hours,
                           time_zone: "America/New_York")
    @url = "https://example.test/societies/#{@event.society_id}/events/#{@event.id}"
  end

  def ics(event = @event) = EventIcs.new(event, url: @url).to_s

  # Unfold continuation lines (CRLF + one space) back into logical lines.
  def lines(text) = text.gsub("\r\n ", "").split("\r\n")
  def prop(text, name) = lines(text).find { |l| l.start_with?("#{name}:") || l.start_with?("#{name};") }

  test "a calendar with one event, CRLF line endings" do
    text = ics
    assert text.start_with?("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n")
    assert text.end_with?("END:VCALENDAR\r\n")
    assert_equal 1, text.scan("BEGIN:VEVENT").size
    assert_no_match(/(?<!\r)\n/, text, "every line ends in CRLF")
  end

  test "start and end are the stored instants in UTC with a Z" do
    assert_equal "DTSTART:20270115T003000Z", prop(ics, "DTSTART")
    assert_equal "DTEND:20270115T023000Z", prop(ics, "DTEND")
  end

  test "summary, location and a description with the society and the event URL" do
    text = ics
    assert_equal "SUMMARY:Zone Night", prop(text, "SUMMARY")
    assert_equal "LOCATION:The den", prop(text, "LOCATION")
    assert_equal "DESCRIPTION:#{EventIcs.escape(@event.society.name)}\\n#{@url}", prop(text, "DESCRIPTION")
    assert_equal "URL:#{@url}", prop(text, "URL")
  end

  test "the UID is stable for an event and differs between events" do
    first = prop(ics, "UID")
    @event.update!(title: "Renamed", location: "Elsewhere")
    assert_equal first, prop(ics(@event.reload), "UID")
    assert_equal "UID:event-#{@event.id}@whiskeysharesociety.com", first
    other = Event.create!(society: @event.society, organizer: users(:john), title: "Other", description: "x",
                          location: "x", start_time: @start, end_time: @start + 1.hour)
    assert_not_equal first, prop(EventIcs.new(other, url: @url).to_s, "UID")
  end

  test "SEQUENCE rises when the time or the location changes, not for other edits" do
    assert_equal "SEQUENCE:0", prop(ics, "SEQUENCE")
    @event.update!(description: "richer copy", title: "New title")
    assert_equal "SEQUENCE:0", prop(ics(@event.reload), "SEQUENCE")
    @event.update!(start_time: @start + 1.hour, end_time: @start + 3.hours)
    assert_equal "SEQUENCE:1", prop(ics(@event.reload), "SEQUENCE")
    @event.update!(location: "The back room")
    assert_equal "SEQUENCE:2", prop(ics(@event.reload), "SEQUENCE")
  end

  test "text values escape backslash, semicolon, comma and newlines" do
    assert_equal "a\\\\b\;c\\,d\\ne\\nf", EventIcs.escape("a\\b;c,d\ne\r\nf")
    @event.update!(title: "Peat, smoke; and \\ more", location: "12 Main St, Athens; GA")
    text = ics(@event.reload)
    assert_equal "SUMMARY:Peat\\, smoke\; and \\\\ more", prop(text, "SUMMARY")
    assert_equal "LOCATION:12 Main St\\, Athens\; GA", prop(text, "LOCATION")
  end

  test "lines are folded at 75 octets without splitting a character" do
    long = "Smoke and sherry " * 6 + "é" * 60 # multibyte across the fold points
    @event.update!(title: long)
    text = ics(@event.reload)
    text.split("\r\n").each do |physical|
      assert_operator physical.bytesize, :<=, 75, "line too long: #{physical.inspect}"
      assert physical.valid_encoding?, "a fold split a UTF-8 character"
    end
    assert_equal "SUMMARY:#{EventIcs.escape(long)}", prop(text, "SUMMARY")
  end

  test "fold works on a bare line" do
    folded = EventIcs.fold("X" * 160)
    parts = folded.split("\r\n")
    assert_equal [ 75, 75, 12 ], parts.map(&:bytesize)
    assert parts[1].start_with?(" ") && parts[2].start_with?(" ")
  end
end
