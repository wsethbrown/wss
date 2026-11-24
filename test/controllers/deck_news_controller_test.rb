require "test_helper"

# The "tell me about new decks" sign-up: form post, confirm link (GET shows a
# button, POST confirms), signed unsubscribe link, rate limits, Turnstile, and
# where the form renders.
class DeckNewsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  EMAIL = "curious.reader@example.com".freeze
  Service = MailingList::SignupService

  setup do
    @saved = ENV.to_h.slice("TURNSTILE_SITE_KEY", "TURNSTILE_SECRET_KEY")
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY].each { |k| ENV.delete(k) }
    clear_enqueued_jobs
  end

  teardown do
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY].each { |k| @saved.key?(k) ? ENV[k] = @saved[k] : ENV.delete(k) }
    RateLimitStore.disable_for_test!
  end

  def mail_jobs = enqueued_jobs.select { |j| j["job_class"] == "ActionMailer::MailDeliveryJob" }
  def last_raw_token = mail_jobs.last["arguments"].last["args"].last
  def subscriber = MailingListSubscriber.find_by(email: EMAIL)

  def make_deck
    deck = Presentation.create!(author: users(:admin), title: "Islay Journey", content: "Smoky.", price: 17.99)
    deck.update_column(:published, true)
    deck
  end

  # --- The whole path ------------------------------------------------------

  test "happy path: request, open the link (nothing changes), confirm, unsubscribe" do
    post deck_news_path, params: { email: EMAIL, source: "library" }, headers: { "HTTP_REFERER" => presentations_url }
    assert_redirected_to presentations_url
    assert_equal Service::REQUEST_MESSAGE, flash[:notice]
    assert_equal 1, mail_jobs.size
    assert_equal "library", subscriber.source
    raw = last_raw_token

    get deck_news_confirmation_path(token: raw)
    assert_response :success
    assert_select "form[action='#{confirm_deck_news_path}'][method='post'] input[name='token'][value='#{raw}']", 1
    assert_select "form button[type='submit']", 1
    assert_nil subscriber.confirmed_at, "opening the link confirms nothing"

    post confirm_deck_news_path, params: { token: raw }
    assert_response :success
    assert subscriber.active?

    token = Service.unsubscribe_token_for(subscriber)
    get deck_news_unsubscribe_path(token: token)
    assert_response :success
    assert_select "form[action='#{deck_news_unsubscribe_path}'][method='post'] input[name='token']", 1
    assert subscriber.active?, "opening the unsubscribe link changes nothing"

    post deck_news_unsubscribe_path, params: { token: token }
    assert_response :success
    assert_not subscriber.active?
    assert subscriber.unsubscribed_at.present?
  end

  test "without a referer the form post lands on the library" do
    post deck_news_path, params: { email: EMAIL, source: "deck" }
    assert_redirected_to presentations_path
  end

  test "an invalid email is refused with a message and nothing is stored or sent" do
    assert_no_difference -> { MailingListSubscriber.count } do
      post deck_news_path, params: { email: "nope", source: "library" }
    end
    assert_redirected_to presentations_path
    assert flash[:alert].present?
    assert_empty mail_jobs
  end

  test "the address never appears in the redirect, the flash or a page" do
    post deck_news_path, params: { email: EMAIL, source: "library" }
    assert_not_includes response.location, "curious"
    assert_not_includes flash[:notice], "curious"
    raw = last_raw_token
    get deck_news_confirmation_path(token: raw)
    assert_not_includes response.body, EMAIL
    post confirm_deck_news_path, params: { token: raw }
    assert_not_includes response.body, EMAIL
    get deck_news_unsubscribe_path(token: Service.unsubscribe_token_for(subscriber))
    assert_not_includes response.body, EMAIL
  end

  # --- Confirm ------------------------------------------------------------

  test "a wrong or expired confirm link is refused on GET and POST with no change" do
    post deck_news_path, params: { email: EMAIL, source: "library" }
    raw = last_raw_token

    get deck_news_confirmation_path(token: "not-the-token")
    assert_redirected_to presentations_path
    assert flash[:alert].present?
    post confirm_deck_news_path, params: { token: "not-the-token" }
    assert_redirected_to presentations_path

    travel Service::EXPIRY + 1.minute do
      get deck_news_confirmation_path(token: raw)
      assert_redirected_to presentations_path
      post confirm_deck_news_path, params: { token: raw }
      assert_redirected_to presentations_path
      assert flash[:alert].present?
    end
    assert_nil subscriber.confirmed_at
  end

  test "confirming twice shows the same page and changes nothing the second time" do
    post deck_news_path, params: { email: EMAIL, source: "library" }
    raw = last_raw_token
    post confirm_deck_news_path, params: { token: raw }
    stamp = subscriber.confirmed_at

    get deck_news_confirmation_path(token: raw)
    assert_response :success
    post confirm_deck_news_path, params: { token: raw }
    assert_response :success
    assert_equal stamp, subscriber.confirmed_at
  end

  test "a second request for a confirmed address sends no mail and answers the same" do
    post deck_news_path, params: { email: EMAIL, source: "library" }
    first_location = response.location
    first_flash = flash.to_h
    post confirm_deck_news_path, params: { token: last_raw_token }
    before = subscriber.attributes
    clear_enqueued_jobs

    post deck_news_path, params: { email: EMAIL.upcase, source: "library" }

    assert_equal first_location, response.location
    assert_equal first_flash, flash.to_h
    assert_empty mail_jobs
    assert_equal before, subscriber.attributes
  end

  # --- Unsubscribe --------------------------------------------------------

  test "unsubscribe needs a valid signature" do
    row = MailingListSubscriber.create!(email: EMAIL, confirmed_at: Time.current)

    get deck_news_unsubscribe_path(token: "forged")
    assert_redirected_to root_path
    post deck_news_unsubscribe_path, params: { token: "forged" }
    assert_redirected_to root_path
    post deck_news_unsubscribe_path
    assert_redirected_to root_path
    post deck_news_unsubscribe_path, params: { token: row.id }
    assert_redirected_to root_path
    assert row.reload.active?
  end

  test "a one-click mail client can unsubscribe without a session or CSRF token" do
    row = MailingListSubscriber.create!(email: EMAIL, confirmed_at: Time.current)
    token = Service.unsubscribe_token_for(row)
    ActionController::Base.allow_forgery_protection = true

    post "#{deck_news_unsubscribe_path}?token=#{CGI.escape(token)}", params: { "List-Unsubscribe" => "One-Click" }
    assert_response :success
    assert_not row.reload.active?
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  # --- Rate limits --------------------------------------------------------

  test "the form is limited per target email across IPs, and the refused request sends nothing" do
    RateLimitStore.enable_for_test!
    DeckNewsController::EMAIL_LIMIT.times do |i|
      post deck_news_path, params: { email: EMAIL, source: "library" }, headers: { "REMOTE_ADDR" => "10.0.0.#{i + 1}" }
      assert_equal Service::REQUEST_MESSAGE, flash[:notice]
    end
    sent = mail_jobs.size
    assert_equal DeckNewsController::EMAIL_LIMIT, sent

    post deck_news_path, params: { email: " #{EMAIL.upcase} ", source: "library" },
                         headers: { "REMOTE_ADDR" => "10.9.9.9", "HTTP_REFERER" => presentations_url }
    assert_redirected_to presentations_url
    assert_response :see_other
    assert_equal RateLimitedResponses::RATE_LIMITED_MESSAGE, flash[:alert]
    assert_equal sent, mail_jobs.size
  end

  test "the form is limited per IP, and the refused request stores and sends nothing" do
    RateLimitStore.enable_for_test!
    DeckNewsController::IP_LIMIT.times do |i|
      post deck_news_path, params: { email: "reader#{i}@example.com", source: "deck" }
    end
    sent = mail_jobs.size
    assert_equal DeckNewsController::IP_LIMIT, sent

    assert_no_difference -> { MailingListSubscriber.count } do
      post deck_news_path, params: { email: "one.more@example.com", source: "deck" }
    end
    assert_equal RateLimitedResponses::RATE_LIMITED_MESSAGE, flash[:alert]
    assert_equal sent, mail_jobs.size

    travel DeckNewsController::WINDOW + 1.second do
      post deck_news_path, params: { email: "one.more@example.com", source: "deck" }
      assert_equal Service::REQUEST_MESSAGE, flash[:notice]
    end
  end

  # --- Turnstile ----------------------------------------------------------

  test "Turnstile on: a missing or rejected check is refused, nothing stored or sent" do
    ENV["TURNSTILE_SITE_KEY"] = "site-key-test"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key-test"

    assert_no_difference -> { MailingListSubscriber.count } do
      post deck_news_path, params: { email: EMAIL, source: "library" }, headers: { "HTTP_REFERER" => presentations_url }
    end
    assert_redirected_to presentations_url
    assert_equal TurnstileProtection::REFUSED_MESSAGE, flash[:alert]

    Turnstile.stubs(:verify).returns(Turnstile::Result.new(status: :rejected, error_codes: [ "invalid-input-response" ]))
    assert_no_difference -> { MailingListSubscriber.count } do
      post deck_news_path, params: { email: EMAIL, source: "library", "cf-turnstile-response" => "bad" }
    end
    assert_redirected_to presentations_path
    assert_equal TurnstileProtection::REFUSED_MESSAGE, flash[:alert]
    assert_empty mail_jobs
  end

  test "Turnstile on: a passed check goes through, and an off-site referer is not followed" do
    ENV["TURNSTILE_SITE_KEY"] = "site-key-test"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key-test"
    Turnstile.stubs(:verify).returns(Turnstile::Result.new(status: :passed, error_codes: []))

    post deck_news_path, params: { email: EMAIL, source: "library", "cf-turnstile-response" => "ok" },
                         headers: { "HTTP_REFERER" => "https://evil.example/elsewhere" }
    assert_redirected_to presentations_path
    assert_equal 1, mail_jobs.size
  end

  # --- Where the form renders ---------------------------------------------

  test "the form is on the library page, with the widget only when Turnstile is on" do
    make_deck
    get presentations_path
    assert_response :success
    assert_select "form#deck-news-form[action='#{deck_news_path}'][method='post']", 1 do
      assert_select "input[type='hidden'][name='source'][value='library']", 1
      assert_select "label[for='deck-news-email']", 1
      assert_select "input#deck-news-email[type='email'][name='email'][required]", 1
      assert_select "button[type='submit'].btn-secondary", 1
      assert_select ".btn-primary", 0
      assert_select ".cf-turnstile", 0
    end
    assert_no_match(/subscri/i, css_select("#deck-news").to_s)

    ENV["TURNSTILE_SITE_KEY"] = "site-key-test"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key-test"
    get presentations_path
    assert_select "form#deck-news-form .cf-turnstile[data-controller='turnstile']", 1
  end

  test "the form is on a deck page for a visitor and a signed-in non-owner (email prefilled)" do
    deck = make_deck
    get presentation_path(deck)
    assert_response :success
    assert_select "form#deck-news-form input[name='source'][value='deck']", 1
    assert_select "input#deck-news-email[value]", 0

    sign_in users(:john)
    get presentation_path(deck)
    assert_select "form#deck-news-form", 1
    assert_select "input#deck-news-email[value='#{users(:john).email}']", 1
  end

  test "the form is not shown to the deck's owner" do
    deck = make_deck
    UserPresentation.create!(user: users(:john), presentation: deck, purchase_type: "direct", purchased_at: Time.current)
    sign_in users(:john)

    get presentation_path(deck)
    assert_response :success
    assert_select "form#deck-news-form", 0
  end
end
