# "Tell me when a new deck is published": the email sign-up for visitors who
# are not ready to buy (shared/_deck_news_form on the library and deck pages).
# No account, no session; the list is MailingListSubscriber and the rules live
# in MailingList::SignupService.
#
#   create               POST /deck_news                 the form
#   confirmation         GET  /deck_news/confirm/:token  one-button page; changes nothing
#   confirm              POST /deck_news/confirm         confirms (token in the body)
#   unsubscribe          GET  /deck_news/unsubscribe     one-button page; changes nothing
#   remove               POST /deck_news/unsubscribe     unsubscribes
#
# Mail scanners follow every link in a message, so neither emailed link acts
# on a GET. The answer to the form is the same whether or not the address is
# already on the list. Emails are personal data: never in a URL, a flash, a
# page title or a log line (the `email` param is filtered globally).
class DeckNewsController < ApplicationController
  include RateLimitedResponses
  include TurnstileProtection

  # Per-IP is a backstop only (shared NATs, one wifi); per-email is the real guard.
  IP_LIMIT = 20      # sign-up requests per IP per window
  EMAIL_LIMIT = 3    # sign-up requests per target email per window
  WINDOW = 15.minutes

  # The form sends real email, so cap it per IP and per target address.
  rate_limit to: IP_LIMIT, within: WINDOW, only: :create, store: RateLimitStore,
             name: "deck-news-ip", with: -> { rate_limit_response("ip") }
  rate_limit to: EMAIL_LIMIT, within: WINDOW, only: :create, store: RateLimitStore,
             name: "deck-news-email", by: -> { rate_limit_email_key(params[:email]) },
             with: -> { rate_limit_response("email") }

  # Bot check (Cloudflare Turnstile), inert until its keys are set. After the
  # rate limits, before any lookup, so the answer never depends on the address.
  before_action :require_turnstile, only: :create

  # RFC 8058 one-click clients (List-Unsubscribe-Post) send no CSRF token; the
  # signed token is the authorization.
  skip_forgery_protection only: :remove

  def create
    result = MailingList::SignupService.request(params[:email], source: params[:source])
    redirect_to form_page, status: :see_other, (result.success? ? :notice : :alert) => result.message
  end

  def confirmation
    unless MailingList::SignupService.pending?(params[:token])
      return refuse_confirm_link("confirm page opened with an invalid or expired token")
    end

    @token = params[:token]
    Rails.logger.info "Deck news confirm page shown; nothing changed yet"
  end

  def confirm
    result = MailingList::SignupService.confirm(params[:token])
    return refuse_confirm_link("confirm posted with an invalid or expired token") if result.invalid?

    render :confirm
  end

  def unsubscribe
    subscriber = MailingList::SignupService.subscriber_for_unsubscribe(params[:token])
    return refuse_unsubscribe_link unless subscriber

    @token = params[:token]
    if subscriber.unsubscribed_at
      Rails.logger.info "Deck news unsubscribe page: subscriber #{subscriber.id} already unsubscribed, showing the done page"
      render :remove
    else
      Rails.logger.info "Deck news unsubscribe page shown for subscriber #{subscriber.id}; nothing changed yet"
    end
  end

  def remove
    subscriber = MailingList::SignupService.unsubscribe(params[:token])
    return refuse_unsubscribe_link unless subscriber

    render :remove
  end

  private

  # Back to the page the form was on (same site only), else the library.
  def form_page
    url_from(request.referer) || presentations_path
  end

  # TurnstileProtection sends a refused request here instead of /auth.
  def turnstile_refusal_location
    form_page
  end

  def refuse_confirm_link(reason)
    Rails.logger.warn "Deck news link refused: #{reason}"
    redirect_to presentations_path, alert: "That link is invalid or has expired."
  end

  # The service has already logged why (never the token).
  def refuse_unsubscribe_link
    redirect_to root_path, alert: "That link is no longer valid."
  end
end
