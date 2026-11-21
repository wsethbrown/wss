require "net/http"

# Cloudflare Turnstile (bot check) for the public sign-up surfaces.
#
# OFF unless BOTH TURNSTILE_SITE_KEY and TURNSTILE_SECRET_KEY are set, so
# development, tests and a deploy without the keys behave exactly as before.
# When on, the widget's token (form field `cf-turnstile-response`) is checked
# server-side with Cloudflare's siteverify endpoint. Anything other than a
# clear success refuses. If Cloudflare cannot be reached, times out or answers
# nonsense, the result is :unavailable and callers refuse (fail closed).
#
# Never logs the token, the secret or an email address.
class Turnstile
  VERIFY_URI = URI("https://challenges.cloudflare.com/turnstile/v0/siteverify").freeze
  ORIGIN = "https://challenges.cloudflare.com".freeze
  RESPONSE_PARAM = "cf-turnstile-response".freeze
  OPEN_TIMEOUT = 3 # seconds
  READ_TIMEOUT = 5 # seconds

  NETWORK_ERRORS = [
    Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError,
    IOError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError
  ].freeze

  # status: :disabled (keys unset), :passed, :missing (no token),
  # :rejected (Cloudflare said no), :unavailable (could not verify).
  Result = Struct.new(:status, :error_codes, keyword_init: true) do
    def passed?
      status == :passed || status == :disabled
    end
  end

  def self.site_key
    ENV["TURNSTILE_SITE_KEY"].presence
  end

  def self.enabled?
    site_key.present? && ENV["TURNSTILE_SECRET_KEY"].present?
  end

  def self.verify(token, remote_ip: nil)
    return Result.new(status: :disabled, error_codes: []) unless enabled?
    return Result.new(status: :missing, error_codes: []) if token.blank?

    form = { "secret" => ENV["TURNSTILE_SECRET_KEY"], "response" => token.to_s, "remoteip" => remote_ip }.compact
    response = post_siteverify(form)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "Turnstile siteverify answered HTTP #{response.code}; treating as unavailable"
      return Result.new(status: :unavailable, error_codes: [])
    end

    body = JSON.parse(response.body.to_s)
    unless body.is_a?(Hash) && [ true, false ].include?(body["success"])
      Rails.logger.error "Turnstile siteverify returned a malformed response; treating as unavailable"
      return Result.new(status: :unavailable, error_codes: [])
    end

    codes = Array(body["error-codes"]).map(&:to_s)
    Result.new(status: body["success"] ? :passed : :rejected, error_codes: codes)
  rescue JSON::ParserError => e
    Rails.logger.error "Turnstile siteverify returned a malformed response (#{e.class}); treating as unavailable"
    Result.new(status: :unavailable, error_codes: [])
  rescue *NETWORK_ERRORS => e
    Rails.logger.error "Turnstile siteverify unreachable (#{e.class}); treating as unavailable"
    Result.new(status: :unavailable, error_codes: [])
  end

  # The one network call, separate so tests can stub it.
  def self.post_siteverify(form)
    Net::HTTP.start(VERIFY_URI.host, VERIFY_URI.port, use_ssl: true,
                    open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT, write_timeout: READ_TIMEOUT) do |http|
      request = Net::HTTP::Post.new(VERIFY_URI)
      request.set_form_data(form)
      http.request(request)
    end
  end
end
