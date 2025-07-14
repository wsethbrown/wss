class WebhooksController < ApplicationController
  # Skip CSRF protection for webhooks
  skip_before_action :verify_authenticity_token
  before_action :authenticate_stripe_webhook

  def stripe
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
    Rails.logger.error "Stripe webhook error: #{e.message}"
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
    user = find_user_by_customer_id(subscription.customer)
    return unless user

    plan_name = extract_plan_name(subscription)

    user.update!(
      stripe_subscription_id: subscription.id,
      subscription_status: subscription.status,
      subscription_plan: plan_name,
      subscription_ends_at: subscription.current_period_end ? Time.at(subscription.current_period_end) : nil
    )

    # Add initial credit for new subscription
    CreditTransaction.grant_monthly_credit(user, "Welcome credit - new subscription")

    Rails.logger.info "Subscription created for user #{user.id}: #{subscription.id}, credit added"
  end

  def handle_subscription_updated(subscription)
    user = find_user_by_customer_id(subscription.customer)
    return unless user

    plan_name = extract_plan_name(subscription)

    user.update!(
      subscription_status: subscription.status,
      subscription_plan: plan_name,
      subscription_ends_at: subscription.current_period_end ? Time.at(subscription.current_period_end) : nil,
      cancel_at_period_end: subscription.cancel_at_period_end
    )

    Rails.logger.info "Subscription updated for user #{user.id}: #{subscription.id} -> #{subscription.status} (cancel_at_period_end: #{subscription.cancel_at_period_end})"
  end

  def handle_subscription_deleted(subscription)
    user = find_user_by_customer_id(subscription.customer)
    return unless user

    user.update!(
      stripe_subscription_id: nil,
      subscription_status: "cancelled",
      subscription_ends_at: subscription.current_period_end ? Time.at(subscription.current_period_end) : Time.current,
      cancel_at_period_end: false
    )
    
    # If subscription is ending immediately (not at period end), expire credits
    if subscription.cancel_at.nil? || subscription.cancel_at <= Time.current.to_i
      CreditTransaction.expire_all_credits(user, "Subscription cancelled")
    end

    Rails.logger.info "Subscription cancelled for user #{user.id}: #{subscription.id}"
  end

  def handle_payment_succeeded(invoice)
    user = find_user_by_customer_id(invoice.customer)
    return unless user

    # Update subscription end date based on successful payment
    if invoice.respond_to?(:subscription) && invoice.subscription
      subscription = Stripe::Subscription.retrieve(invoice.subscription)
      user.update!(
        subscription_ends_at: subscription.current_period_end ? Time.at(subscription.current_period_end) : nil
      )

      # Add credit for recurring subscription payments (not initial subscription creation)
      if invoice.billing_reason == "subscription_cycle"
        CreditTransaction.grant_monthly_credit(user, "Monthly subscription renewal")
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice.id}, credit added for renewal"
      else
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice.id}"
      end
    elsif invoice.lines && invoice.lines.data.any? { |line| line.type == "subscription" }
      # Handle invoice lines that are subscription related
      subscription_id = invoice.lines.data.find { |line| line.type == "subscription" }&.subscription
      if subscription_id
        subscription = Stripe::Subscription.retrieve(subscription_id)
        user.update!(
          subscription_ends_at: subscription.current_period_end ? Time.at(subscription.current_period_end) : nil
        )
        Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice.id} (via invoice lines)"
      end
    else
      Rails.logger.info "Payment succeeded for user #{user.id}: #{invoice.id} (non-subscription)"
    end
  end

  def handle_payment_failed(invoice)
    user = find_user_by_customer_id(invoice.customer)
    return unless user

    # Mark subscription as past due or failed
    user.update!(subscription_status: "past_due")

    Rails.logger.warn "Payment failed for user #{user.id}: #{invoice.id}"
  end

  def handle_checkout_completed(session)
    # Handle presentation purchases
    if session.mode == "payment" && session.metadata&.dig("presentation_id").present?
      user_id = session.metadata["user_id"]
      presentation_id = session.metadata["presentation_id"]
      
      user = User.find_by(id: user_id)
      unless user
        Rails.logger.error "User not found for checkout session: #{session.id}, user_id: #{user_id}"
        return
      end

      # Check if presentation purchase already exists (prevent duplicates)
      existing_purchase = UserPresentation.find_by(user: user, presentation_id: presentation_id)
      if existing_purchase
        Rails.logger.info "Presentation purchase already exists: user #{user.id}, presentation #{presentation_id}"
        return
      end

      # Get the payment intent to retrieve the amount paid
      payment_intent = Stripe::PaymentIntent.retrieve(session.payment_intent)
      
      # Create user_presentation record for direct purchase
      UserPresentation.create!(
        user: user,
        presentation_id: presentation_id,
        purchase_type: 'direct',
        purchase_price: payment_intent.amount / 100.0, # Convert from cents
        stripe_payment_intent_id: payment_intent.id,
        purchased_at: Time.current
      )

      Rails.logger.info "Direct presentation purchase completed: user #{user.id}, presentation #{presentation_id}, session #{session.id}"
    elsif session.mode == "subscription" && session.metadata&.dig("plan").present?
      # Handle subscription creation from checkout
      # This is already handled by customer.subscription.created event
      Rails.logger.info "Subscription checkout completed: #{session.id}"
    end
  end

  def find_user_by_customer_id(customer_id)
    User.find_by(stripe_customer_id: customer_id).tap do |user|
      Rails.logger.error "User not found for Stripe customer: #{customer_id}" unless user
    end
  end

  def extract_plan_name(subscription)
    # Extract plan name from subscription items
    price_id = subscription.items.data.first&.price&.id

    case price_id
    when ENV["STRIPE_MONTHLY_PRICE_ID"]
      "monthly"
    when ENV["STRIPE_QUARTERLY_PRICE_ID"]
      "quarterly"
    when ENV["STRIPE_YEARLY_PRICE_ID"]
      "yearly"
    else
      Rails.logger.warn "Unknown price ID: #{price_id}"
      "unknown"
    end
  end
end
