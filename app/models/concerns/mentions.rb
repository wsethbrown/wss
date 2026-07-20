# Tagging a member in an event comment: "Thanks for hosting @EthanFrank".
#
# Comment bodies stay plain text. A mention is not a record, it is a handle
# written in the text and resolved when the comment is saved or displayed, so
# nothing has to be migrated and a comment reads the same everywhere.
#
# Resolution is deliberately strict, and fails CLOSED:
#   - only members of that event's society can be tagged, so a comment can't
#     be used to probe for people elsewhere on the site;
#   - a handle matching two members resolves to NOBODY. Handles are derived
#     from names and are not unique, and linking or notifying the wrong Ethan
#     Frank is worse than leaving the text plain (owner decision).
# Anything unresolved just stays as the characters the author typed.
module Mentions
  # Handles are letters and digits only, which is what User#handle produces.
  # The leading boundary stops an email address ("a@b.com") reading as a tag.
  PATTERN = /(?<![\w.])@([A-Za-z0-9]+)/

  module_function

  # Every @handle written in the text, lowercased and deduped.
  def handles_in(text)
    text.to_s.scan(PATTERN).flatten.map(&:downcase).uniq
  end

  # => { "ethanfrank" => #<User> }, only for handles matching exactly one
  # candidate. Ambiguous and unknown handles are absent by design.
  def resolve(text, candidates)
    wanted = handles_in(text)
    return {} if wanted.empty?

    by_handle = candidates.group_by { |user| user.handle.to_s.downcase }
    wanted.filter_map { |handle|
      found = by_handle[handle]
      [ handle, found.first ] if found && found.size == 1
    }.to_h
  end

  # Who can be tagged on an event: the society's active members. Mirrors who
  # EventPolicy#comment? lets speak, so tagging can't reach further than the
  # conversation does.
  def candidates_for(event)
    event.society.society_memberships.where(status: "active").includes(:user).map(&:user).uniq
  end

  def users_in(text, event)
    resolve(text, candidates_for(event)).values
  end
end
