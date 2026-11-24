require "test_helper"

class MailingListMailerTest < ActionMailer::TestCase
  setup { @subscriber = MailingListSubscriber.create!(email: "curious.reader@example.com") }

  test "confirmation goes to the address with the confirm link in both parts" do
    mail = MailingListMailer.confirmation(@subscriber, "rawtoken123")

    assert_equal [ "curious.reader@example.com" ], mail.to
    assert_equal "Confirm your email to hear about new decks", mail.subject
    assert_includes mail.html_part.body.to_s, "/deck_news/confirm/rawtoken123"
    assert_includes mail.text_part.body.to_s, "/deck_news/confirm/rawtoken123"
  end

  test "confirmation carries a working unsubscribe link and the List-Unsubscribe headers" do
    mail = MailingListMailer.confirmation(@subscriber, "rawtoken123")

    header = mail["List-Unsubscribe"].value
    url = header[/\A<(.+)>\z/, 1]
    assert_match(%r{/deck_news/unsubscribe\?token=}, url)
    assert_equal "List-Unsubscribe=One-Click", mail["List-Unsubscribe-Post"].value
    token = Rack::Utils.parse_query(URI(url).query)["token"]
    assert_equal @subscriber, MailingList::SignupService.subscriber_for_unsubscribe(token)

    assert_includes mail.html_part.body.to_s, CGI.escapeHTML(url)
    assert_includes mail.text_part.body.to_s, url
  end

  test "the body does not use the word the paid membership uses" do
    mail = MailingListMailer.confirmation(@subscriber, "rawtoken123")
    [ mail.subject, mail.html_part.body.to_s.gsub(%r{https?://\S+}, ""), mail.text_part.body.to_s.gsub(%r{https?://\S+}, "") ].each do |text|
      assert_no_match(/subscri/i, text)
    end
  end
end
