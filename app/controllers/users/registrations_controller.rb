class Users::RegistrationsController < Devise::RegistrationsController
  include TurnstileProtection
  include RateLimitedResponses

  # Password sign-up creates a users row for whoever asks; per-IP backstop.
  SIGN_UP_IP_LIMIT = 20 # sign-up attempts per IP per window
  SIGN_UP_WINDOW = 15.minutes

  rate_limit to: SIGN_UP_IP_LIMIT, within: SIGN_UP_WINDOW, only: :create, store: RateLimitStore,
             name: "sign-up-ip", with: -> { rate_limit_response("ip") }

  # Bot check (Cloudflare Turnstile) on password sign-up, inert until its keys
  # are set. Password sign-in for existing accounts is not gated (rate limits).
  before_action :require_turnstile, only: [ :create ]
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]
  before_action :refuse_email_change, only: [ :update ]

  def create
    super do |resource|
      if resource.persisted?
        # Mark password as manually set for normal registrations
        resource.update_column(:password_set_manually, true)
      end
    end
  end

  # Self-service deletion is disabled: User#destroy cascades into other members'
  # data and leaves Stripe billing running (docs/redesign/ACCOUNT_DELETION.md).
  # Deliberately does not call super.
  def destroy
    Rails.logger.info "[Account] Self-service deletion refused for user #{current_user&.id.inspect}; redirected to contact"
    redirect_to contact_path, notice: "To delete your account, please contact us."
  end

  protected

  # B8 (S6): the email is the sign-in credential, so it changes only through
  # the account page, where the new mailbox must confirm. The form still posts
  # the current address; only a real change is refused.
  def refuse_email_change
    submitted = params.dig(:user, :email)
    return if submitted.nil?
    return if Auth::EmailChangeService.normalize(submitted) == Auth::EmailChangeService.normalize(current_user.email)

    Rails.logger.warn "[Account] Email change through registration update refused for user #{current_user.id}; use the account page"
    redirect_to account_path, alert: "To change your email address, use the Email address section of your account page."
  end

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ], except: [ :email ])
  end
end
