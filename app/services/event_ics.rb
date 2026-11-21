# One event as an iCalendar file (RFC 5545), written by hand: no gem.
#
# - UID is stable per event (event-<id>@whiskeysharesociety.com), so a calendar
#   that imports the file again, or the "updated" email's attachment, replaces
#   its copy instead of adding a second one.
# - SEQUENCE is events.calendar_sequence, raised when the time or the location
#   changes (Event#bump_calendar_sequence).
# - DTSTART/DTEND are the stored instants in UTC with a Z suffix, which every
#   client converts to the viewer's zone; no VTIMEZONE block is needed.
# - Text is escaped (backslash, semicolon, comma, newline) and every content
#   line is folded at 75 octets without splitting a UTF-8 character.
class EventIcs
  UID_DOMAIN = "whiskeysharesociety.com".freeze
  CRLF = "\r\n".freeze
  FOLD_OCTETS = 75

  def initialize(event, url:)
    @event = event
    @url = url
  end

  def to_s
    lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Whiskey Share Society//Events//EN",
      "CALSCALE:GREGORIAN",
      "METHOD:PUBLISH",
      "BEGIN:VEVENT",
      "UID:#{uid}",
      "DTSTAMP:#{self.class.utc(Time.current)}",
      "SEQUENCE:#{@event.calendar_sequence.to_i}",
      "DTSTART:#{self.class.utc(@event.start_time)}",
      "DTEND:#{self.class.utc(@event.end_time || @event.start_time + 2.hours)}",
      "SUMMARY:#{self.class.escape(@event.title)}"
    ]
    lines << "LOCATION:#{self.class.escape(@event.location)}" if @event.location.present?
    lines << "DESCRIPTION:#{self.class.escape("#{@event.society.name}\n#{@url}")}"
    lines << "URL:#{@url}"
    lines.push("END:VEVENT", "END:VCALENDAR")
    lines.map { |line| self.class.fold(line) }.join(CRLF) + CRLF
  end

  def uid = "event-#{@event.id}@#{UID_DOMAIN}"

  def filename = "#{@event.title.to_s.parameterize.presence || "event-#{@event.id}"}.ics"

  def self.utc(time) = time.utc.strftime("%Y%m%dT%H%M%SZ")

  # TEXT value escaping (RFC 5545 3.3.11).
  def self.escape(text)
    text.to_s.gsub("\\") { "\\\\" }.gsub(";", "\;").gsub(",", "\\,").gsub(/\r\n|\r|\n/, "\\n")
  end

  # Content-line folding (RFC 5545 3.1): at most 75 octets per physical line,
  # continuation lines start with one space; characters are never split.
  def self.fold(line)
    out = []
    current = +""
    limit = FOLD_OCTETS
    line.each_char do |char|
      if current.bytesize + char.bytesize > limit
        out << current
        current = +" "
        limit = FOLD_OCTETS
      end
      current << char
    end
    out << current
    out.join(CRLF)
  end
end
