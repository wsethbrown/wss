require "test_helper"
require "minitest/mock"

# B5 / M1, M4: the renewal webhook (invoice.payment_succeeded with
# billing_reason subscription_cycle) grants through the same per-month ledger
# key as the daily job, and refreshes the member's status from Stripe first so
# a recovered past-due payment still earns that month's credit.
class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @user.update!(stripe_customer_id: "cus_b5_webhook", stripe_subscription_id: "sub_b5",
                  subscription_plan: "monthly", subscription_status: "active",
                  subscription_ends_at: 20.days.from_now)
    @period_end = 30.days.from_now.to_i
  end

  test "a past-due member whose retry succeeds receives that month's credit" do
    @user.update!(subscription_status: "past_due")
    MonthlyCreditJob.perform_now
    assert_equal 0, @user.reload.credits, "no credit while past due"

    post_cycle_invoice("evt_b5_retry", retrieved_status: "active")

    assert_response :success
    assert_equal "active", @user.reload.subscription_status
    assert_equal 1, @user.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "renewal webhook and daily job in one month grant once" do
    post_cycle_invoice("evt_b5_cycle_1", retrieved_status: "active")
    assert_equal 1, @user.reload.credits

    @user.update!(subscription_ends_at: Time.current.change(day: [ Time.current.day, 28 ].min) + 1.month)
    MonthlyCreditJob.perform_now
    post_cycle_invoice("evt_b5_cycle_2", retrieved_status: "active")
    assert_equal 1, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "a cycle invoice for a subscription Stripe reports as canceled grants nothing" do
    post_cycle_invoice("evt_b5_canceled", retrieved_status: "canceled")
    assert_equal 0, @user.reload.credits
  end

  # ---------------------------------------------------------------------------
  # B6 / M3: stale and out-of-order subscription events. State is written from a
  # fresh Stripe::Subscription.retrieve, and events for a subscription that is
  # not the member's current one are ignored (a newer `created` is adopted).
  # ---------------------------------------------------------------------------

  test "a late created(incomplete) after updated(active) leaves the member active" do
    with_retrieved("sub_b5" => fresh_sub("sub_b5", "active")) do
      post_event("evt_b6_updated", "customer.subscription.updated", sub_payload("sub_b5", "active"))
      post_event("evt_b6_late_created", "customer.subscription.created", sub_payload("sub_b5", "incomplete"))
    end
    assert_response :success
    assert_equal "active", @user.reload.subscription_status
    assert_equal "sub_b5", @user.stripe_subscription_id
  end

  test "a deleted event for an old subscription changes nothing" do
    CreditTransaction.record!(user: @user, amount: 2, transaction_type: "granted", description: "setup")
    @user.update!(stripe_subscription_id: "sub_new", founding_member: true, subscription_plan: "founding_monthly")
    before = @user.reload.attributes.except("updated_at")

    post_event("evt_b6_old_deleted", "customer.subscription.deleted",
               sub_payload("sub_old", "canceled").merge(cancel_at: nil))

    assert_response :success
    assert_equal before, @user.reload.attributes.except("updated_at")
    assert_equal 2, @user.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "a deleted event for the current subscription cancels it with Stripe's spelling" do
    CreditTransaction.record!(user: @user, amount: 2, transaction_type: "granted", description: "setup")
    post_event("evt_b6_deleted", "customer.subscription.deleted", sub_payload("sub_b5", "canceled").merge(cancel_at: nil))

    assert_response :success
    @user.reload
    assert_equal "canceled", @user.subscription_status
    assert_nil @user.stripe_subscription_id
    assert_equal 2, @user.credits, "unused credits are kept when the membership ends"
  end

  # Owner rule: credits are not wiped when a membership ends; a lapsed member
  # just cannot spend them until they rejoin.
  test "a deleted subscription keeps the unused balance and logs it" do
    CreditTransaction.record!(user: @user, amount: 3, transaction_type: "granted", description: "setup")
    logged = capture_log do
      assert_no_difference -> { CreditTransaction.count } do
        post_event("evt_keep_credits", "customer.subscription.deleted",
                   sub_payload("sub_b5", "canceled").merge(cancel_at: nil))
      end
    end

    assert_response :success
    @user.reload
    assert_equal 3, @user.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
    assert_not CreditTransaction.where(user: @user, transaction_type: "expired").exists?
    kept_line = logged.lines.grep(/kept \d+ unused credits/).join
    assert_match(/user #{@user.id}\b.*kept 3 unused credits/, kept_line)
    assert_no_match(/@/, kept_line, "no email addresses in the log line")
  end

  test "an updated event for an old subscription changes nothing" do
    @user.update!(stripe_subscription_id: "sub_new")
    with_retrieved("sub_old" => fresh_sub("sub_old", "canceled")) do
      post_event("evt_b6_old_updated", "customer.subscription.updated", sub_payload("sub_old", "canceled"))
    end
    assert_response :success
    assert_equal "active", @user.reload.subscription_status
    assert_equal "sub_new", @user.stripe_subscription_id
  end

  test "a newer created subscription replaces the current one; an older one does not" do
    @user.update!(stripe_subscription_id: "sub_mid")
    subs = {
      "sub_mid" => fresh_sub("sub_mid", "active", created: 10.days.ago),
      "sub_older" => fresh_sub("sub_older", "incomplete_expired", created: 20.days.ago),
      "sub_newer" => fresh_sub("sub_newer", "active", created: 1.minute.ago)
    }
    with_retrieved(subs) do
      post_event("evt_b6_older_created", "customer.subscription.created", sub_payload("sub_older", "incomplete"))
      assert_equal "sub_mid", @user.reload.stripe_subscription_id
      assert_equal "active", @user.subscription_status

      post_event("evt_b6_newer_created", "customer.subscription.created", sub_payload("sub_newer", "incomplete"))
    end
    assert_equal "sub_newer", @user.reload.stripe_subscription_id
    assert_equal "active", @user.subscription_status
  end

  test "an updated event writes Stripe's current state, not the payload" do
    with_retrieved("sub_b5" => fresh_sub("sub_b5", "past_due")) do
      post_event("evt_b6_stale_updated", "customer.subscription.updated", sub_payload("sub_b5", "active"))
    end
    assert_equal "past_due", @user.reload.subscription_status
  end

  # ---------------------------------------------------------------------------
  # B6 / M8: a claim whose handler never finished is re-claimable after 10 min.
  # ---------------------------------------------------------------------------

  test "a crash between claim and completion is reprocessed on redelivery, exactly once" do
    StripeEvent.claim("evt_b6_crashed", "invoice.payment_succeeded") # handler died here

    post_cycle_invoice("evt_b6_crashed", retrieved_status: "active")
    assert_response :conflict, "a fresh claim is still in flight; Stripe should retry later"
    assert_equal "in_progress", JSON.parse(response.body)["status"]
    assert_equal 0, @user.reload.credits

    travel 11.minutes do
      post_cycle_invoice("evt_b6_crashed", retrieved_status: "active")
      assert_response :success
      assert_equal 1, @user.reload.credits
      assert StripeEvent.find_by(stripe_event_id: "evt_b6_crashed").processed_at.present?

      post_cycle_invoice("evt_b6_crashed", retrieved_status: "active")
      assert_equal "already_processed", JSON.parse(response.body)["status"]
    end
    travel 30.minutes do
      post_cycle_invoice("evt_b6_crashed", retrieved_status: "active")
      assert_equal "already_processed", JSON.parse(response.body)["status"]
    end
    assert_equal 1, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  # ---------------------------------------------------------------------------
  # B6 / M5, M15: deck fulfilment on the webhook path.
  # ---------------------------------------------------------------------------

  test "a fulfilment error returns 5xx and releases the claim so Stripe retries" do
    deck = paid_deck
    UserPresentation.stubs(:create!).raises(ActiveRecord::ConnectionNotEstablished, "db blip")
    post_event("evt_b6_fulfil", "checkout.session.completed", deck_session(deck))
    assert_response :internal_server_error
    assert_not StripeEvent.exists?(stripe_event_id: "evt_b6_fulfil"), "claim released"
    UserPresentation.unstub(:create!)

    post_event("evt_b6_fulfil", "checkout.session.completed", deck_session(deck))
    assert_response :success
    assert deck.purchased_by?(@user)
  end

  test "a delayed payment method is fulfilled when async_payment_succeeded arrives" do
    deck = paid_deck
    post_event("evt_b6_async_1", "checkout.session.completed", deck_session(deck, payment_status: "unpaid"))
    assert_not deck.purchased_by?(@user), "not paid yet"

    post_event("evt_b6_async_2", "checkout.session.async_payment_succeeded", deck_session(deck))
    assert_response :success
    assert deck.purchased_by?(@user)
  end

  # ---------------------------------------------------------------------------
  # B6 / M10: the society-only plan is decided from the Stripe price id, so a
  # founding-society checkout earns no deck credit whichever event lands first.
  # ---------------------------------------------------------------------------

  test "a founding-society checkout grants no deck credit when the invoice arrives first" do
    founding_society_checkout(order: %i[invoice created checkout])
  end

  test "a founding-society checkout grants no deck credit when created arrives first" do
    founding_society_checkout(order: %i[created checkout invoice])
  end

  test "a regular first invoice still grants the welcome credit" do
    @user.update!(stripe_subscription_id: nil, subscription_plan: nil, subscription_status: nil)
    with_retrieved("sub_reg" => fresh_sub("sub_reg", "active", price: "price_b6_monthly")) do
      post_event("evt_b6_reg_inv", "invoice.payment_succeeded", first_invoice("sub_reg"))
    end
    assert_equal 1, @user.reload.credits
  end

  # ---------------------------------------------------------------------------
  # B6 follow-up: a Stripe failure while re-fetching the subscription. Transient
  # errors release the claim and answer 5xx so Stripe retries; a subscription
  # Stripe no longer knows is acknowledged (200) and changes nothing.
  # ---------------------------------------------------------------------------

  TRANSIENT_STRIPE_ERRORS = [
    -> { Stripe::APIConnectionError.new("connection reset") },
    -> { Stripe::RateLimitError.new("too many requests") }
  ].freeze

  %w[customer.subscription.updated customer.subscription.created].each do |type|
    TRANSIENT_STRIPE_ERRORS.each do |error|
      klass = error.call.class
      test "#{type}: a transient #{klass.name} on retrieve returns 5xx, releases the claim and changes nothing" do
        event_id = "evt_b6_transient_#{type.split('.').last}_#{klass.name.demodulize}"
        CreditTransaction.record!(user: @user, amount: 1, transaction_type: "granted", description: "setup")
        before = subscription_snapshot

        Stripe::Subscription.stubs(:retrieve).raises(error.call)
        post_event(event_id, type, sub_payload("sub_b5", "incomplete"))
        Stripe::Subscription.unstub(:retrieve)

        assert_response :internal_server_error
        assert_not StripeEvent.exists?(stripe_event_id: event_id), "claim released"
        assert_equal before, subscription_snapshot

        # Stripe's redelivery of the same event is processed, not skipped.
        with_retrieved("sub_b5" => fresh_sub("sub_b5", "past_due")) do
          post_event(event_id, type, sub_payload("sub_b5", "incomplete"))
        end
        assert_response :success
        assert_equal "success", JSON.parse(response.body)["status"]
        assert_equal "past_due", @user.reload.subscription_status
        assert StripeEvent.processed?(event_id)
        assert_equal 1, @user.credits
        assert_equal CreditTransaction.balance_for(@user), @user.credits
      end
    end

    test "#{type}: a subscription Stripe no longer knows is acknowledged, logged and changes nothing" do
      event_id = "evt_b6_gone_#{type.split('.').last}"
      CreditTransaction.record!(user: @user, amount: 1, transaction_type: "granted", description: "setup")
      before = subscription_snapshot

      Rails.logger.stubs(:warn)
      Rails.logger.expects(:warn).with(regexp_matches(/sub_b5 for user #{@user.id} could not be retrieved from Stripe/)).once
      Stripe::Subscription.stubs(:retrieve).raises(Stripe::InvalidRequestError.new("No such subscription: 'sub_b5'", "id"))
      post_event(event_id, type, sub_payload("sub_b5", "incomplete"))
      Stripe::Subscription.unstub(:retrieve)

      assert_response :success
      assert StripeEvent.processed?(event_id), "acknowledged; Stripe will not retry"
      assert_equal before, subscription_snapshot
    end
  end

  private

  # Subscription fields plus the ledger, for "changes nothing" assertions.
  def subscription_snapshot
    @user.reload
    [ @user.attributes.slice(*%w[stripe_subscription_id subscription_status subscription_plan subscription_ends_at
                                 cancel_at_period_end subscription_paused_at credits founding_member]),
      CreditTransaction.where(user: @user).order(:id).pluck(:id, :amount) ]
  end

  def founding_society_checkout(order:)
    @user.update!(stripe_subscription_id: nil, subscription_plan: nil, subscription_status: nil)
    sub = fresh_sub("sub_fs", "active", price: "price_b6_fs")
    with_env("STRIPE_FOUNDING_SOCIETY_PRICE_ID" => "price_b6_fs") do
      with_retrieved("sub_fs" => sub) do
        order.each do |step|
          case step
          when :invoice then post_event("evt_fs_inv_#{order.first}", "invoice.payment_succeeded", first_invoice("sub_fs"))
          when :created then post_event("evt_fs_created_#{order.first}", "customer.subscription.created",
                                        sub_payload("sub_fs", "incomplete", price: "price_b6_fs"))
          when :checkout then post_event("evt_fs_checkout_#{order.first}", "checkout.session.completed",
                                         { id: "cs_fs", object: "checkout.session", mode: "subscription",
                                           customer: "cus_b5_webhook", metadata: { plan: "founding_society", user_id: @user.id.to_s } })
          end
          assert_response :success
        end
      end
    end
    assert_equal 0, @user.reload.credits
    assert_equal 0, CreditTransaction.where(user: @user).count
    assert_equal "founding_society", @user.subscription_plan
  end

  def first_invoice(sub_id)
    { id: "in_first_#{sub_id}", object: "invoice", customer: "cus_b5_webhook",
      billing_reason: "subscription_create", parent: { subscription_details: { subscription: sub_id } } }
  end

  def paid_deck
    deck = Presentation.create!(author: users(:admin), title: "B6 Deck", content: "A story.", price: 12.00)
    deck.update_column(:published, true)
    deck
  end

  def deck_session(deck, payment_status: "paid")
    { id: "cs_b6", object: "checkout.session", mode: "payment", payment_status: payment_status,
      payment_intent: nil, metadata: { user_id: @user.id.to_s, presentation_id: deck.id.to_s } }
  end

  def sub_payload(id, status, price: "price_b6_monthly")
    { id: id, object: "subscription", customer: "cus_b5_webhook", status: status,
      items: { data: [ { id: "si_#{id}", current_period_end: @period_end, price: { id: price } } ] } }
  end

  # What Stripe::Subscription.retrieve returns (2024-06-20 shape).
  def fresh_sub(id, status, created: 1.day.ago, price: "price_b6_monthly")
    Stripe::Subscription.construct_from(
      id: id, object: "subscription", customer: "cus_b5_webhook", status: status,
      created: created.to_i, current_period_end: @period_end, cancel_at_period_end: false,
      pause_collection: nil, items: { data: [ { id: "si_#{id}", price: { id: price } } ] }
    )
  end

  def with_retrieved(subs)
    subs.each { |id, sub| Stripe::Subscription.stubs(:retrieve).with(id).returns(sub) }
    yield
  ensure
    Stripe::Subscription.unstub(:retrieve)
  end

  def with_env(vars)
    old = vars.keys.index_with { |k| ENV[k] }
    vars.each { |k, v| ENV[k] = v }
    yield
  ensure
    old.each { |k, v| ENV[k] = v }
  end

  def capture_log
    io = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old
  end

  def post_event(event_id, type, object)
    payload = { id: event_id, type: type, data: { object: object } }.to_json
    post webhooks_stripe_path, params: payload, headers: signed_headers(payload)
  end

  def post_cycle_invoice(event_id, retrieved_status:)
    payload = {
      id: event_id,
      type: "invoice.payment_succeeded",
      data: { object: {
        id: "in_#{event_id}", object: "invoice", customer: "cus_b5_webhook",
        billing_reason: "subscription_cycle",
        parent: { subscription_details: { subscription: "sub_b5" } }
      } }
    }.to_json
    retrieved = { "id" => "sub_b5", "status" => retrieved_status, "current_period_end" => @period_end }
    Stripe::Subscription.stub(:retrieve, retrieved) do
      post webhooks_stripe_path, params: payload, headers: signed_headers(payload)
    end
  end

  def signed_headers(payload)
    secret = Rails.configuration.stripe[:webhook_secret]
    timestamp = Time.now.to_i
    signature = Stripe::Webhook::Signature.compute_signature(Time.at(timestamp), payload, secret)
    { "Stripe-Signature" => "t=#{timestamp},v1=#{signature}", "Content-Type" => "application/json" }
  end
end
