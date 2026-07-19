class WebhooksController < ApplicationController
  include ActivityLogger
  
  # Skip CSRF protection for webhooks
  skip_before_action :verify_authenticity_token
  before_action :authenticate_stripe_webhook

  def stripe
    # Idempotency: process each Stripe event exactly once. Retried/duplicate deliveries
    # (which Stripe sends routinely) return 200 without re-running the handler, so we
    # never double-grant credits.
    unless StripeEvent.claim(@event.id, @event.type)
      Rails.logger.info "Stripe event #{@event.id} already processed; skipping"
      return render json: { status: "already_processed" }
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
    when "checkout.session.completed"
      handle_checkout_completed(@event.data.object)
    else
      Rails.logger.info "Unhandled Stripe event: #{@event.type}"
    end

    render json: { status: "success" }
  rescue => e
    # Release the claim so Stripe's retry can reprocess this event, and return 500 so
    # Stripe knows to retry.
    StripeEvent.release(@event.id) if @event
    Rails.logger.error "Stripe webhook error (#{@event&.id}): #{e.message}"
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

  def handle_subscription_created(subscription)
    customer_id = subscription.try(:customer) || subscription["customer"]
    user = find_user_by_customer_id(customer_id)
    return unless user

    plan_name = extract_plan_name(subscription)

    period_end = subscription_period_end(subscription)

    user.update!(
      stripe_subscription_id: subscription.try(:id) || subscription["id"],
      subscription_status: subscription.try(:status) || subscription["status"],
      subscription_plan: plan_name,
      subscription_ends_at: period_end ? Time.at(period_end) : nil
    )

    grant_founding_status(user, plan_name)

    # NOTE: the welcome credit is granted on invoice.payment_succeeded
    # (billing_reason subscription_create), not here, this event arrives
    # with status "incomplete" during checkout, so an active-subscription
    # guard would (and once did) silently swallow the credit.
    subscription_id = subscription.try(:id) || subscription["id"]
    log_activity_for_user(user, :subscription_created, nil, { plan: plan_name, stripe_id: subscription_id })

    Rails.logger.info "Subscription created for user #{user.id}: #{subscription_id}"
  end

  def handle_subscription_updated(subscription)
    customer_id = subscription.try(:customer) || subscription["customer"]
    user = find_user_by_customer_id(customer_id)
    return unless user

    plan_name = extract_plan_name(subscription)

    period_end = subscription_period_end(subscription)
    cancel_at_period_end = subscription.try(:cancel_at_period_end) || subscription["cancel_at_period_end"]

    # Check for pause collection information
    pause_collection = subscription.try(:pause_collection) || subscription["pause_collection"]
    is_paused = pause_collection.present?
    
    # Determine final status
    final_status = subscription.try(:status) || subscription["status"]
    paused_at = is_paused ? Time.current : nil
    
    user.update!(
      subscription_status: final_status,
      subscription_plan: plan_name,
      subscription_ends_at: period_end ? Time.at(period_end) : nil,
      cancel_at_period_end: cancel_at_period_end,
      subscription_paused_at: paused_at
    )

    # Pausing does NOT touch founding status (owner rule); only deletion does.
    grant_founding_status(user, plan_name)
    
    # Log activity if subscription was canceled
    if cancel_at_period_end
      log_activity_for_user(user, :subscription_canceled, nil, { plan: plan_name, ends_at: period_end })
    end
    
    # Log activity if subscription was paused/resumed
    if is_paused && user.subscription_paused_at_previously_was.nil?
      log_activity_for_user(user, :subscription_paused, nil, { plan: plan_name })
    elsif !is_paused && user.subscription_paused_at_previously_was.present?
      log_activity_for_user(user, :subscription_resumed, nil, { plan: plan_name })
    end

    subscription_id = subscription.try(:id) || subscription["id"]
    status = subscription.try(:status) || subscription["status"]
    Rails.logger.info "Subscription updated for user #{user.id}: #{subscription_id} -> #{status} (cancel_at_period_end: #{cancel_at_period_end}, paused: #{is_paused})"
  end

  def handle_subscription_deleted(subscription)
    customer_id = subscription.try(:customer) || subscription["customer"]
    user = find_user_by_customer_id(customer_id)
    return unless user

    period_end = subscription_period_end(subscription)

    user.update!(
      stripe_subscription_id: nil,
      subscription_status: "cancelled",
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

    subscription_id = subscription.try(:id) || subscription["id"]
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
        CreditTransaction.grant_monthly_credit(user, "Monthly subscription renewal")
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}, credit added for renewal"
      when "subscription_create"
        # The welcome credit's webhook path (fallback behind the synchronous
        # grant on the checkout success redirect). No active-status guard:
        # our subscription_status row can still say "incomplete" here, and a
        # successful first payment IS the proof.
        if CreditTransaction.grant_welcome_credit(user)
          log_activity_for_user(user, :credits_added, nil, { amount: 1, reason: "new_subscription" })
          Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}, welcome credit added"
        else
          Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}, welcome credit already granted"
        end
      else
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice_id}"
      end
    elsif (invoice.try(:lines) || invoice["lines"])
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
      Presentations::CheckoutFulfillment.fulfill!(session)
    elsif mode == "subscription" && metadata && (metadata["plan"] || metadata.try(:[], "plan"))
      # Handle subscription creation from checkout
      # This is already handled by customer.subscription.created event
      session_id = session.try(:id) || session["id"]
      Rails.logger.info "Subscription checkout completed: #{session_id}"
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
    items_data = items.try(:data) || items["data"] || []
    first_item = items_data.first
    
    if first_item
      price = first_item.try(:price) || first_item["price"]
      price_id = price.try(:id) || price["id"] if price
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
