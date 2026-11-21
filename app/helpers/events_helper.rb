module EventsHelper
  # Render a comment body with resolved @mentions turned into profile links.
  #
  # ORDER MATTERS AND IS SECURITY-CRITICAL: escape the whole body FIRST, then
  # substitute links into the escaped text. Linkifying first and escaping
  # after would either destroy the links or, worse, let a comment inject
  # markup. Handles are [A-Za-z0-9] only, so nothing unescaped is added.
  #
  # An unresolved handle (nobody, or two people of that name) is left exactly
  # as typed: see Mentions for why that fails closed.
  def comment_body_with_mentions(comment)
    resolved = Mentions.resolve(comment.body, Mentions.candidates_for(comment.event))
    escaped = ERB::Util.html_escape(comment.body)

    escaped.gsub(Mentions::PATTERN) { |raw|
      user = resolved[Regexp.last_match(1).downcase]
      next raw unless user

      # Discord-style: the body stores the compact @handle, but it renders as
      # "@Display Name" in a subtle pill. link_to escapes the name, so a name
      # with punctuation ("O'Brien") stays safe.
      link_to("@#{user.full_name}", profile_path(user),
              class: "mention-pill")
    }.html_safe
  end

  # Google Calendar's "add event" template link for an event (no API, no
  # account link): the same instants as the .ics, in UTC.
  def google_calendar_url(event)
    finish = event.end_time || event.start_time + 2.hours
    params = {
      action: "TEMPLATE",
      text: event.title,
      dates: "#{EventIcs.utc(event.start_time)}/#{EventIcs.utc(finish)}",
      details: "#{event.society.name}\n#{society_event_url(event.society, event)}",
      location: event.location.to_s
    }
    "https://calendar.google.com/calendar/render?#{params.to_query}"
  end
end
