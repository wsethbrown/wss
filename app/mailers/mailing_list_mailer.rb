# Mail to the deck-news list (MailingListSubscriber): for now only the
# confirm-your-address mail. Any mail added here must call
# list_unsubscribe_for(subscriber) and show @unsubscribe_url in its body.
class MailingListMailer < ApplicationMailer
  include MailingListUnsubscribe

  # The raw token is in the link only; the row holds its digest
  # (MailingList::SignupService). Opening the link shows a confirm button.
  def confirmation(subscriber, token)
    @confirm_url = deck_news_confirmation_url(token: token)
    list_unsubscribe_for(subscriber)

    mail(to: subscriber.email, subject: "Confirm your email to hear about new decks")
  end
end
