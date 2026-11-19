# Mail jobs carry raw sign-in / invitation / email-change tokens as positional
# arguments. Active Job logs arguments at info and `filter_parameters` does not
# apply to them, so switch argument logging off for mail delivery (I1).
#
# Delivery is also retried on transient network/SMTP failures (a provider 429
# during an event fan-out, a blip on a magic link) instead of silently losing
# the email (I6). Permanent errors (bad address, auth failure, 5xx) are not retried.
require "net/smtp"

ActiveSupport.on_load(:action_mailer) do
  ActionMailer::MailDeliveryJob.log_arguments = false

  ActionMailer::MailDeliveryJob.retry_on(
    Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::ECONNRESET,
    Errno::ETIMEDOUT, SocketError, EOFError, Net::SMTPServerBusy,
    wait: :polynomially_longer, attempts: 5
  )
end
