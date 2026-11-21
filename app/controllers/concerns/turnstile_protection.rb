# Refuses a request whose Cloudflare Turnstile check does not pass. A no-op
# while Turnstile is off (keys unset). Used as a before_action on the public
# sign-up surfaces: MagicLinksController#create and
# Users::RegistrationsController#create. Runs before the email is looked up,
# so the refusal is the same whether or not the address has an account.
module TurnstileProtection
  extend ActiveSupport::Concern

  REFUSED_MESSAGE = "We couldn't confirm you're a person. Please complete the check and try again.".freeze
  UNAVAILABLE_MESSAGE = "We couldn't run the security check just now, so nothing was sent. Please try again in a minute.".freeze

  private

  def require_turnstile
    result = Turnstile.verify(params[Turnstile::RESPONSE_PARAM], remote_ip: request.remote_ip)
    return if result.passed?

    where = "#{controller_path}##{action_name} from #{request.remote_ip}"
    if result.status == :unavailable
      # Fail closed: a bot check we cannot run is a check that did not pass.
      Rails.logger.error "Turnstile check could not run for #{where}; request refused"
      message = UNAVAILABLE_MESSAGE
    else
      codes = result.error_codes.presence&.join(",")
      Rails.logger.warn "Turnstile refused #{where} (#{result.status}#{" #{codes}" if codes})"
      message = REFUSED_MESSAGE
    end
    redirect_to auth_path, alert: message, status: :see_other
  end
end
