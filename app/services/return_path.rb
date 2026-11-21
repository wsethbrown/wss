# The only gate for a post-sign-in return target. A value is accepted only
# when it is a same-site path: a string starting with exactly one "/", no
# backslash, whitespace, control or encoded line-break characters, no scheme
# or host once parsed, and not one of the sign-in pages (that would loop).
# Everything else is nil, and callers fall back to the dashboard.
module ReturnPath
  MAX_LENGTH = 2000
  SIGN_IN_PREFIXES = %w[/auth /users/sign_in /users/auth /magic_links /invitations].freeze

  def self.sanitize(value)
    return nil unless value.is_a?(String)
    return nil if value.empty? || value.length > MAX_LENGTH
    return nil unless value.start_with?("/")
    return nil if value.start_with?("//")
    return nil if value.match?(/[\\\s[:cntrl:]]/) || value.match?(/%0[ad]/i)

    uri = URI.parse(value)
    return nil if uri.scheme || uri.host
    return nil if SIGN_IN_PREFIXES.any? { |prefix| uri.path == prefix || uri.path.start_with?("#{prefix}/") }

    value
  rescue URI::InvalidURIError
    nil
  end
end
