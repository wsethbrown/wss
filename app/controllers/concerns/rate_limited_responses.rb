# Shared 429 handling for rate-limited controllers. Logs the refusal (never
# the raw email or any token) and answers in the format the caller expects.
module RateLimitedResponses
  extend ActiveSupport::Concern

  RATE_LIMITED_MESSAGE = "Too many attempts. Please wait a few minutes and try again.".freeze

  private

  def rate_limit_response(scope)
    Rails.logger.warn "Rate limit hit on #{controller_name}##{action_name} (#{scope}) from #{request.remote_ip}" \
                      "#{current_user ? " user #{current_user.id}" : ''}"
    if request.format.json?
      render json: { error: RATE_LIMITED_MESSAGE }, status: :too_many_requests
    else
      # Browser and Turbo form posts: send the person back where they were with
      # the message in the flash (303 so Turbo follows it with a GET).
      redirect_back fallback_location: (current_user ? account_path : auth_path),
                    allow_other_host: false, status: :see_other, alert: RATE_LIMITED_MESSAGE
    end
  end

  # Stable, non-reversible cache key part for an email address.
  def rate_limit_email_key(email)
    Digest::SHA256.hexdigest(email.to_s.strip.downcase)[0, 16]
  end
end
