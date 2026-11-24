# Every mail to the deck-news list must be easy to stop. Call
# list_unsubscribe_for(subscriber) before mail(...) in any mailer that writes
# to a MailingListSubscriber: it sets the List-Unsubscribe headers (RFC 8058
# one-click, for mail clients) and @unsubscribe_url for the link in the body
# (see DeckNewsController#unsubscribe / #remove). Same shape as
# EventMailer#mail_with_unsubscribe.
module MailingListUnsubscribe
  extend ActiveSupport::Concern

  private

  def list_unsubscribe_for(subscriber)
    @unsubscribe_url = deck_news_unsubscribe_url(token: MailingList::SignupService.unsubscribe_token_for(subscriber))
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
    @unsubscribe_url
  end
end
