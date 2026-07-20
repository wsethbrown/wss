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

      link_to("@#{user.handle}", profile_path(user),
              class: "font-semibold text-whiskey-700 hover:text-whiskey-600")
    }.html_safe
  end
end
