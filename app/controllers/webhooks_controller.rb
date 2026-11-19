class WebhooksController < ApplicationController
  include ActivityLogger

  # Skip CSRF protection for webhooks
  skip_before_action :verify_authenticity_token
  before_action :authenticate_stripe_webhook

  def stripe
    # Idempotency: process each Stripe event exactly once. Retried/duplicate deliveries
    # (which Stripe sends routinely) return 200 without re-running the handler, so we
    # never double-grant credits. A delivery that finds another claim still in flight
    # gets a 409 so Stripe retries later; if that claim's handler died (deploy, kill),
    # the retry re-claims it once it is STALE_CLAIM_AFTER old (M8).
    unless StripeEvent.claim(@event.id, @event.type)
      if StripeEvent.processed?(@event.id)
        Rails.logger.info "Stripe event #{@event.id} already processed; skipping"
        return render json: { status: "already_processed" }
      end
      Rails.logger.warn "Stripe event #{@event.id} (#{@event.type}) is claimed but not yet processed; asking Stripe to retry later"
      return render json: { status: "in_progress" }, status: :conflict
    end

    case @event.type
    when "customer.subscription.created"
      handle_subscription_created(@event.data.object)
    when "customer.subscription.updated"
      handle_subscription_updated(@event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(@event.data.object)
    when "invoice.payment_succeeded"
      handle_payment_succeeded(@event.data.object)
    when "invoice.payment_failed"
      handle_payment_failed(@event.data.object)
    when "checkout.session.completed", "checkout.session.async_payment_succeeded"
      # async_payment_succeeded (M15) is how a delayed payment method (bank
      # debit and the like) reports that the money arrived; completed fired
      # earlier with payment_status "unpaid" and fulfilment refused then.
      handle_checkout_completed(@event.data.object)
    when "checkout.session.async_payment_failed"
      session = @event.data.object
      Rails.logger.warn "Checkout #{session.try(:id)}: delayed payment failed; nothing granted"
    else
      Rails.logger.info "Unhandled Stripe event: #{@event.type}"
    end

    StripeEvent.mark_processed(@event.id)
    render json: { status: "success" }
  rescue => e
    # Release the claim so Stripe's retry can reprocess this event, and return 500 so
    # Stripe knows to retry.
    StripeEvent.release(@event.id) if @event
    Rails.logger.error "Stripe webhook error (#{@event&.id}, #{@event&.type}): #{e.class}: #{e.message}"
    render json: { error: "Webhook processing failed" }, status: 500
  end

  private

  def authenticate_stripe_webhook
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]
    endpoint_secret = Rails.configuration.stripe[:webhook_secret]

    begin
      @event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
    rescue JSON::ParserError
      render json: { error: "Invalid payload" }, status: 400
      nil
    rescue Stripe::SignatureVerificationError
      render json: { error: "Invalid signature" }, status: 400
      nil
    end
  end

  # --- Subscription events (M3) -------------------------------------------
  # Stripe does not deliver events in order, and retries can arrive days late.
  # So the event payload is only used to find the member and the subscription
  # id; the state we write comes from a fresh Stripe::Subscription.retrieve.
  # Events for a subscription other than the member's current one are ignored,
  # except a `created` for a NEWER subscription, which becomes current.

  def handle_subscription_created(payload)
    user = find_user_by_customer_id(payload.try(:customer) || payload["customer"])
    return unless user

    subscription_id = payload.try(:id) || payload["id"]
    subscription = retrieve_subscription(subscription_id, user)
    return unless subscription
    return unless newer_or_current_subscription?(user, subscription)

    plan_name = apply_subscription_state(user, subscription, adopt: true)
    grant_founding_status(user, plan_name)

    # NOTE: the welcome credit is granted on invoice.payment_succeeded
    # (billing_reason subscription_create), not here, this event arrives
    # with status "incomplete" during checkout, so an active-subscription
    # guard would (and once did) silently swallow the credit.
    log_activity_for_user(user, :subscription_created, nil, { plan: plan_name, stripe_id: subscription_id })

    Rails.logger.info "Subscription created for user #{user.id}: #{subscription_id} -> #{user.subscription_status} (plan #{plan_name})"
  end

  def handle_subscription_updated(payload)
    user = find_user_by_customer_id(payload.try(:customer) || payload["customer"])
    return unless user

    subscription_id = payload.try(:id) || payload["id"]
    return if not_current_subscription?(user, subscription_id, "customer.subscription.updated")

    subscription = retrieve_subscription(subscription_id, user)
    return unless subscription

    status = subscription.try(:status) || subscription["status"]
    adopt = user.stripe_subscription_id.blank?
    if adopt && TERMINAL_STATUSES.include?(status)
      Rails.logger.info "Subscription updated for user #{user.id}: #{subscription_id} is #{status} and not tracked; ignoring"
      return
    end

    was_paused = user.subscription_paused_at.present?
    plan_name = apply_subscription_state(user, subscription, adopt: adopt)
    is_paused = user.subscription_paused_at.present?
    cancel_at_period_end = user.cancel_at_period_end

    # Pausing does NOT touch founding status (owner rule); only deletion does.
    grant_founding_status(user, plan_name)

    # Log activity if subscription was canceled
    if cancel_at_period_end
      log_activity_for_user(user, :subscription_canceled, nil, { plan: plan_name, ends_at: user.subscription_ends_at&.to_i })
    end

    # Log activity if subscription was paused/resumed
    if is_paused && !was_paused
      log_activity_for_user(user, :subscription_paused, nil, { plan: plan_name })
    elsif !is_paused && was_paused
      log_activity_for_user(user, :subscription_resumed, nil, { plan: plan_name })
    end

    Rails.logger.info "Subscription updated for user #{user.id}: #{subscription_id} -> #{status} (cancel_at_period_end: #{cancel_at_period_end}, paused: #{is_paused}#{', now current' if adopt})"
  end

  # A deleted subscription is final, so the payload is authoritative here and
  # no retrieve is needed; the current-subscription check is what matters.
  def handle_subscription_deleted(subscription)
    customer_id = subscription.try(:customer) || subscription["customer"]
    user = find_user_by_customer_id(customer_id)
    return unless user

    subscription_id = subscription.try(:id) || subscription["id"]
    return if not_current_subscription?(user, subscription_id, "customer.subscription.deleted")

    period_end = subscription_period_end(subscription)

    user.update!(
      stripe_subscription_id: nil,
      subscription_status: "canceled",
      subscription_ends_at: period_end ? Time.at(period_end) : Time.current,
      cancel_at_period_end: false
    )

    # Founding status dies with a cancel, permanently (owner rule: cancel only;
    # pausing never lands here). founding_revoked_at bars ever re-earning it.
    if user.founding_member?
      user.update!(founding_member: false, founding_revoked_at: Time.current)
      Rails.logger.info "Founding member status revoked for user #{user.id} (subscription cancelled)"
    end

    # If subscription is ending immediately (not at period end), expire credits
    cancel_at = subscription.try(:cancel_at) || subscription["cancel_at"]
    if cancel_at.nil? || cancel_at <= Time.current.to_i
      CreditTransaction.expire_all_credits(user, "Subscription cancelled")
    end

    Rails.logger.info "Subscription cancelled for user #{user.id}: #{subscription_id}"
  end

  def handle_payment_succeeded(invoice)
    customer_id = invoice.try(:customer) || invoice["customer"]
    user = find_user_by_customer_id(customer_id)
    return unless user

    # Update subscription end date based on successful payment
    subscription_id = invoice_subscription_id(invoice)
    if subscription_id
      subscription = Stripe::Subscription.retrieve(subscription_id)
      period_end = subscription_period_end(subscription)
      user.update!(
        subscription_ends_at: period_end ? Time.at(period_end) : nil
      )

      billing_reason = invoice.try(:billing_reason) || invoice["billing_reason"]
      invoice_id = invoice.try(:id) || invoice["id"]
      case billing_reason
      when "subscription_cycle"
        # M4: refresh status (and pause) from the subscription we just
        # retrieved before granting. A past_due member whose retry succeeded
        # is active again in Stripe, but our row still says past_due until
        # customer.subscription.updated arrives, which would silently skip
        # the credit. The grant shares the daily job's per-month ledger key.
        refresh_subscription_state(user, subscription)
        outcome = CreditTransaction.grant_monthly_credit(user, "Monthly subscription renewal")
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}, renewal credit #{outcome}"
      when "subscription_create"
        # The welcome credit's webhook path (fallback behind the synchronous
        # grant on the checkout success redirect). No active-status guard:
        # our subscription_status row can still say "incomplete" here, and a
        # successful first payment IS the proof.
        #
        # M10: this invoice can beat customer.subscription.created, so the
        # plan on our row may not be written yet. Decide it from the price id
        # of the subscription we just retrieved, so the society-only founding
        # plan never earns a welcome credit whichever event lands first.
        record_plan_from_price(user, subscription)
        if CreditTransaction.grant_welcome_credit(user)
          log_activity_for_user(user, :credits_added, nil, { amount: 1, reason: "new_subscription" })
          Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}, welcome credit added"
        else
          Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}, welcome credit already granted"
        end
      else
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}"
      end
    elsif invoice.try(:lines) || invoice["lines"]
      # Handle invoice lines that are subscription related
      lines_data = invoice.try(:lines).try(:data) || invoice.dig("lines", "data") || []
      subscription_line = lines_data.find { |line| line_subscription_id(line) }
      if subscription_line
        subscription_id = line_subscription_id(subscription_line)
        subscription = Stripe::Subscription.retrieve(subscription_id)
        period_end = subscription_period_end(subscription)
        user.update!(
          subscription_ends_at: period_end ? Time.at(period_end) : nil
        )
        invoice_id = invoice.try(:id) || invoice["id"]
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id} (via invoice lines)"
      end
    else
      invoice_id = invoice.try(:id) || invoice["id"]
      Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id} (non-subscription)"
    end
  end

  def handle_payment_failed(invoice)
    customer_id = invoice.try(:customer) || invoice["customer"]
    user = find_user_by_customer_id(customer_id)
    return unless user

    subscription_id = invoice_subscription_id(invoice)
    return if subscription_id && not_current_subscription?(user, subscription_id, "invoice.payment_failed")

    # Mark subscription as past due or failed
    user.update!(subscription_status: "past_due")

    invoice_id = invoice.try(:id) || invoice["id"]
    Rails.logger.warn "Payment failed for user #{user.id}: #{invoice_id}"
  end

  def handle_checkout_completed(session)
    # Handle presentation purchases
    metadata = session.try(:metadata) || session["metadata"]
    mode = session.try(:mode) || session["mode"]

    if mode == "payment" && metadata && (metadata["presentation_id"] || metadata.try(:[], "presentation_id"))
      # Same code path the post-checkout return uses, so the two can never
      # drift; both are idempotent, whichever arrives first wins.
      # raise_errors: an unexpected error must reach the rescue in #stripe,
      # which releases the claim and answers 5xx so Stripe retries (M5).
      Presentations::CheckoutFulfillment.fulfill!(session, raise_errors: true)
    elsif mode == "subscription" && metadata && (metadata["plan"] || metadata.try(:[], "plan"))
      # Handle subscription creation from checkout
      # This is already handled by customer.subscription.created event
      session_id = session.try(:id) || session["id"]
      Rails.logger.info "Subscription checkout completed: #{session_id}"
    end
  end

  # Stripe statuses after which a subscription never becomes live again.
  TERMINAL_STATUSES = %w[canceled incomplete_expired].freeze

  # The subscription as Stripe has it now. A subscription Stripe no longer
  # knows is a permanent condition (logged, event acknowledged); any other
  # Stripe error propagates so the event is released and retried.
  def retrieve_subscription(subscription_id, user)
    Stripe::Subscription.retrieve(subscription_id)
  rescue Stripe::InvalidRequestError => e
    Rails.logger.warn "Subscription #{subscription_id} for user #{user.id} could not be retrieved from Stripe (#{e.message}); ignoring event"
    nil
  end

  # True (and logged) when the event is for a subscription other than the
  # member's current one. A member with no tracked subscription has nothing to
  # protect, so the event is not ignored on these grounds.
  def not_current_subscription?(user, subscription_id, event_type)
    current = user.stripe_subscription_id
    return false if current.blank? || current == subscription_id

    Rails.logger.info "Ignoring #{event_type} for user #{user.id}: #{subscription_id} is not their current subscription #{current}"
    true
  end

  # For `created`: the event's subscription may become current if the member
  # has none, it already is current, or it is newer than the current one (or
  # the current one no longer exists in Stripe).
  def newer_or_current_subscription?(user, subscription)
    subscription_id = subscription.try(:id) || subscription["id"]
    current_id = user.stripe_subscription_id
    return true if current_id.blank? || current_id == subscription_id

    current = begin
      Stripe::Subscription.retrieve(current_id)
    rescue Stripe::InvalidRequestError => e
      Rails.logger.warn "Current subscription #{current_id} for user #{user.id} not found in Stripe (#{e.message}); #{subscription_id} replaces it"
      return true
    end

    created = (subscription.try(:created) || subscription["created"]).to_i
    current_created = (current.try(:created) || current["created"]).to_i
    if created > current_created
      Rails.logger.info "Subscription #{subscription_id} for user #{user.id} is newer than current #{current_id}; replacing it"
      true
    else
      Rails.logger.info "Ignoring customer.subscription.created for user #{user.id}: #{subscription_id} is older than current #{current_id}"
      false
    end
  end

  # Writes a freshly retrieved subscription's state onto the user. adopt: also
  # make it the member's current subscription. Returns the plan name.
  def apply_subscription_state(user, subscription, adopt:)
    status = subscription.try(:status) || subscription["status"]
    paused = (subscription.try(:pause_collection) || subscription["pause_collection"]).present?
    period_end = subscription_period_end(subscription)
    plan_name = extract_plan_name(subscription)

    attrs = {
      subscription_status: status,
      subscription_plan: plan_name,
      subscription_ends_at: period_end ? Time.at(period_end) : nil,
      cancel_at_period_end: (subscription.try(:cancel_at_period_end) || subscription["cancel_at_period_end"]) ? true : false,
      subscription_paused_at: paused ? (user.subscription_paused_at || Time.current) : nil
    }
    attrs[:stripe_subscription_id] = subscription.try(:id) || subscription["id"] if adopt
    user.update!(attrs)
    plan_name
  end

  # First invoice only: record the plan the price id names, if it names one.
  def record_plan_from_price(user, subscription)
    plan_name = extract_plan_name(subscription)
    return if plan_name == "unknown" || user.subscription_plan == plan_name

    previous = user.subscription_plan
    user.update!(subscription_plan: plan_name)
    Rails.logger.info "First payment for user #{user.id}: plan set from price id #{previous.inspect} -> #{plan_name.inspect}"
  end

  # Writes the retrieved subscription's status and pause state onto the user
  # (subscription_cycle only). A missing status leaves the row as it was.
  def refresh_subscription_state(user, subscription)
    status = subscription.try(:status) || subscription["status"]
    return Rails.logger.warn("Renewal for user #{user.id}: retrieved subscription has no status; keeping #{user.subscription_status.inspect}") if status.blank?

    paused = (subscription.try(:pause_collection) || subscription["pause_collection"]).present?
    attrs = { subscription_status: status }
    attrs[:subscription_paused_at] = paused ? (user.subscription_paused_at || Time.current) : nil
    previous = user.subscription_status
    user.update!(attrs)
    if previous != status
      Rails.logger.info "Renewal for user #{user.id}: subscription status refreshed from Stripe #{previous.inspect} -> #{status.inspect}"
    end
  end

  # The webhook endpoint is pinned to API version 2025-05-28.basil while our
  # direct API calls pin Stripe.api_version 2024-06-20, so objects arrive in
  # BOTH shapes. Basil removed subscription.current_period_end (it now lives on
  # each subscription item), read whichever is present.
  def subscription_period_end(subscription)
    period_end = subscription.try(:current_period_end) || subscription["current_period_end"]
    return period_end if period_end

    items = subscription.try(:items) || subscription["items"]
    items_data = items.try(:data) || (items && items["data"]) || []
    items_data.filter_map { |item| item.try(:current_period_end) || item["current_period_end"] }.max
  end

  # Basil moved invoice.subscription to invoice.parent.subscription_details.subscription.
  def invoice_subscription_id(invoice)
    sub = invoice.try(:subscription) || invoice["subscription"]
    return sub if sub

    parent = invoice.try(:parent) || invoice["parent"]
    return nil unless parent

    details = parent.try(:subscription_details) || parent["subscription_details"]
    details && (details.try(:subscription) || details["subscription"])
  end

  # Basil moved line.subscription to line.parent.subscription_item_details.subscription.
  def line_subscription_id(line)
    sub = line.try(:subscription) || line["subscription"]
    return sub if sub

    parent = line.try(:parent) || line["parent"]
    return nil unless parent

    details = parent.try(:subscription_item_details) || parent["subscription_item_details"]
    details && (details.try(:subscription) || details["subscription"])
  end

  def find_user_by_customer_id(customer_id_obj)
    # Handle both string customer IDs and customer objects
    customer_id = customer_id_obj.is_a?(String) ? customer_id_obj : (customer_id_obj.try(:id) || customer_id_obj["id"] || customer_id_obj)

    User.find_by(stripe_customer_id: customer_id).tap do |user|
      Rails.logger.error "User not found for Stripe customer: #{customer_id}" unless user
    end
  end

  def extract_plan_name(subscription)
    # Extract plan name from subscription items
    items = subscription.try(:items) || subscription["items"]
    items_data = items.try(:data) || (items && items["data"]) || []
    first_item = items_data.first

    if first_item
      price = first_item.try(:price) || first_item["price"]
      price_id = price.try(:id) || price["id"] if price
    end

    if price_id.blank?
      Rails.logger.warn "Subscription #{subscription.try(:id) || subscription['id']} has no price id; plan unknown"
      return "unknown"
    end

    case price_id
    when ENV["STRIPE_MONTHLY_PRICE_ID"]
      "monthly"
    when ENV["STRIPE_QUARTERLY_PRICE_ID"]
      "quarterly"
    when ENV["STRIPE_YEARLY_PRICE_ID"]
      "yearly"
    when ENV["STRIPE_FOUNDING_SOCIETY_PRICE_ID"]
      "founding_society"
    when ENV["STRIPE_FOUNDING_MONTHLY_PRICE_ID"]
      "founding_monthly"
    else
      Rails.logger.warn "Unknown price ID: #{price_id}"
      "unknown"
    end
  end

  # Taking a founding plan grants founding status, unless it was ever revoked
  # (revocation is permanent). Idempotent; checkout enforces the 50-slot cap,
  # this just records the status the paid plan implies.
  def grant_founding_status(user, plan_name)
    return unless User::FOUNDING_PLANS.include?(plan_name)
    return if user.founding_member? || user.founding_revoked_at.present?

    user.update!(founding_member: true)
    Rails.logger.info "Founding member status granted to user #{user.id} (#{plan_name})"
  end
end
