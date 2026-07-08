class SubscriptionsController < ApplicationController
  include ActivityLogger

  before_action :authenticate_user!
  protect_from_forgery with: :exception

  def create_checkout_session
    price_id = params[:price_id]

    # Define price IDs for each plan (these will be your Stripe Price IDs)
    price_ids = {
      "monthly" => ENV.fetch("STRIPE_MONTHLY_PRICE_ID", "price_monthly"),
      "quarterly" => ENV.fetch("STRIPE_QUARTERLY_PRICE_ID", "price_quarterly"),
      "yearly" => ENV.fetch("STRIPE_YEARLY_PRICE_ID", "price_yearly")
    }

    unless price_ids.key?(price_id)
      redirect_to account_path(anchor: "subscription"), alert: "Invalid subscription plan"
      return
    end

    begin
      # Get or create Stripe customer
      customer = get_or_create_stripe_customer

      # ALWAYS check Stripe for active subscriptions first - this is the source of truth
      begin
        active_subscriptions = Stripe::Subscription.list(
          customer: customer.id,
          status: 'active',
          limit: 100
        )

        trialing_subscriptions = Stripe::Subscription.list(
          customer: customer.id,
          status: 'trialing',
          limit: 100
        )

        if active_subscriptions.data.any? || trialing_subscriptions.data.any?
          Rails.logger.warn "User #{current_user.email} has #{active_subscriptions.data.count} active and #{trialing_subscriptions.data.count} trialing subscription(s) in Stripe"

          # If we have active subscriptions but no stored ID, sync the first one
          if current_user.stripe_subscription_id.blank?
            first_sub = active_subscriptions.data.first || trialing_subscriptions.data.first
            current_user.update!(
              stripe_subscription_id: first_sub.id,
              subscription_status: first_sub.status
            )
          end

          redirect_to account_path(anchor: "subscription"), alert: "You already have an active subscription. Please manage it from your account page."
          return
        end
      rescue Stripe::StripeError => e
        Rails.logger.error "Error checking for active subscriptions: #{e.message}"
        redirect_to account_path(anchor: "subscription"), alert: "Error checking subscription status. Please try again."
        return
      end

      # Clear any stored subscription ID since we verified there are no active subscriptions
      if current_user.stripe_subscription_id.present?
        Rails.logger.info "Clearing stored subscription ID #{current_user.stripe_subscription_id} for user #{current_user.email} since no active subscriptions exist"
        current_user.update!(
          stripe_subscription_id: nil,
          subscription_status: nil,
          subscription_plan: nil
        )
      end

      # Create Stripe checkout session. payment_method_types is intentionally
      # omitted: Checkout then offers every method enabled in the Stripe
      # Dashboard (card, Apple Pay, Link, ...). automatic_payment_methods is a
      # PaymentIntents-only parameter and is rejected by the Checkout API.
      session = Stripe::Checkout::Session.create({
        customer: customer.id,
        line_items: [ {
          price: price_ids[price_id],
          quantity: 1
        } ],
        mode: "subscription",
        success_url: account_url + "?subscription=success#subscription",
        cancel_url: account_url + "?subscription=cancelled#subscription",
        metadata: {
          # Stripe stores metadata values as strings; be explicit so the value
          # round-trips identically when the webhook reads it back.
          user_id: current_user.id.to_s,
          plan: price_id
        }
      })

      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      Rails.logger.error "Stripe error details: #{e.inspect}"

      # Handle specific Stripe errors with better user messages
      error_message = case e.message
      when /test clock customer.*already has.*active subscription/i
        "This test account has reached the maximum number of test subscriptions. Please contact support to reset your test account."
      when /customer.*already has.*active subscription/i
        "You already have an active subscription. Please cancel it first or contact support."
      when /no such customer/i
        "Customer account not found. Please try again or contact support."
      else
        "Payment processing error. Please try again or contact support."
      end

      redirect_to account_path(anchor: "subscription"), alert: error_message
    end
  end

  def portal
    # Redirect to Stripe Customer Portal for subscription management
    return redirect_to account_path(anchor: "subscription"), alert: "No active subscription found" unless current_user.stripe_customer_id

    begin
      session = Stripe::BillingPortal::Session.create({
        customer: current_user.stripe_customer_id,
        return_url: account_url + "#subscription"
      })

      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe portal error: #{e.message}"
      redirect_to account_path(anchor: "subscription"), alert: "Unable to access billing portal. Please try again."
    end
  end

  def cancel
    return redirect_to account_path(anchor: "subscription"), alert: "No active subscription found" unless current_user.stripe_subscription_id

    begin
      # Cancel the subscription at period end (users keep access until current period expires)
      subscription = Stripe::Subscription.update(
        current_user.stripe_subscription_id,
        { cancel_at_period_end: true }
      )

      # Update the user's cancel_at_period_end flag
      current_user.update!(cancel_at_period_end: true)

      redirect_to account_path(anchor: "subscription"), notice: "Subscription will be cancelled at the end of your current billing period."
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe cancellation error: #{e.message}"
      redirect_to account_path(anchor: "subscription"), alert: "Unable to cancel subscription. Please try again."
    end
  end

  def plans
    # Redirect non-subscribers to home page
    unless current_user.stripe_subscription_id.present?
      redirect_to root_path, alert: "Please subscribe to access plan options"
      return
    end

    # Fetch available plans
    @stripe_products = fetch_stripe_products
    @current_plan = current_user.subscription_plan || 'monthly'
  end

  def change_plan
    new_plan = params[:plan]
    price_ids = {
      "monthly" => ENV.fetch("STRIPE_MONTHLY_PRICE_ID", "price_monthly"),
      "quarterly" => ENV.fetch("STRIPE_QUARTERLY_PRICE_ID", "price_quarterly"),
      "yearly" => ENV.fetch("STRIPE_YEARLY_PRICE_ID", "price_yearly")
    }

    unless price_ids.key?(new_plan)
      redirect_to subscriptions_plans_path, alert: "Invalid subscription plan"
      return
    end

    return redirect_to subscriptions_plans_path, alert: "No active subscription found" unless current_user.stripe_subscription_id

    begin
      # Get current subscription
      subscription = Stripe::Subscription.retrieve(current_user.stripe_subscription_id)

      # Update the subscription to the new plan
      update_params = {
        items: [ {
          id: subscription.items.data[0].id,
          price: price_ids[new_plan]
        } ],
        proration_behavior: "create_prorations"
      }

      # If subscription is pending cancellation, reactivate it
      if subscription.cancel_at_period_end
        update_params[:cancel_at_period_end] = false
      end

      updated_subscription = Stripe::Subscription.update(
        current_user.stripe_subscription_id,
        update_params
      )

      # Update our local record
      current_user.update!(
        subscription_plan: new_plan,
        cancel_at_period_end: false
      )

      notice_message = if subscription.cancel_at_period_end
        "Subscription reactivated and updated to #{new_plan.capitalize} plan!"
      else
        "Subscription updated to #{new_plan.capitalize} plan!"
      end
      redirect_to account_path(anchor: "subscription"), notice: notice_message
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe plan change error: #{e.message}"
      redirect_to subscriptions_plans_path, alert: "Unable to change plan. Please try again."
    end
  end

  # NOTE: pause/resume must live above `private` — they are routed actions
  # (POST /subscriptions/pause|resume). They were previously defined below the
  # `private` keyword, which made them non-public and 404'd the live feature.
  def pause
    unless current_user.stripe_subscription_id.present?
      redirect_to account_path(anchor: "subscription"), alert: "No active subscription found."
      return
    end

    begin
      # Pause payment collection using Stripe API
      Stripe::Subscription.update(
        current_user.stripe_subscription_id,
        {
          pause_collection: {
            behavior: 'keep_as_draft',
            resumes_at: 1.month.from_now.to_i  # Auto-resume after 1 month
          }
        }
      )

      current_user.update!(
        subscription_paused_at: Time.current,
        subscription_status: 'paused'
      )

      Rails.logger.info "User #{current_user.email} paused subscription #{current_user.stripe_subscription_id}"
      redirect_to account_path(anchor: "subscription"), notice: "Subscription paused successfully. Billing will resume automatically in 1 month."
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe pause error: #{e.message}"
      redirect_to account_path(anchor: "subscription"), alert: "Unable to pause subscription. Please try again."
    end
  end

  def resume
    unless current_user.stripe_subscription_id.present?
      redirect_to account_path(anchor: "subscription"), alert: "No active subscription found."
      return
    end

    begin
      # Resume payment collection using Stripe API
      Stripe::Subscription.update(
        current_user.stripe_subscription_id,
        { pause_collection: '' }  # Empty string removes the pause
      )

      current_user.update!(
        subscription_paused_at: nil,
        subscription_status: 'active'
      )

      Rails.logger.info "User #{current_user.email} resumed subscription #{current_user.stripe_subscription_id}"
      redirect_to account_path(anchor: "subscription"), notice: "Subscription resumed successfully. Billing will continue normally."
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe resume error: #{e.message}"
      redirect_to account_path(anchor: "subscription"), alert: "Unable to resume subscription. Please try again."
    end
  end

  private

  def get_or_create_stripe_customer
    if current_user.stripe_customer_id.present?
      begin
        # Try to retrieve existing customer
        customer = Stripe::Customer.retrieve(current_user.stripe_customer_id)

        # Check if customer exists and is not deleted
        if customer.deleted?
          # Customer was deleted in Stripe, create a new one
          raise Stripe::InvalidRequestError.new("Customer was deleted", nil)
        end

        customer
      rescue Stripe::InvalidRequestError => e
        # Customer doesn't exist or was deleted, create a new one
        Rails.logger.info "Creating new Stripe customer for #{current_user.email} (previous customer not found)"

        customer = Stripe::Customer.create({
          email: current_user.email,
          name: current_user.full_name,
          metadata: {
            user_id: current_user.id
          }
        })

        # Update customer ID
        current_user.update!(stripe_customer_id: customer.id)
        customer
      end
    else
      # Create new customer
      customer = Stripe::Customer.create({
        email: current_user.email,
        name: current_user.full_name,
        metadata: {
          user_id: current_user.id.to_s
        }
      })

      # Save customer ID to user
      current_user.update!(stripe_customer_id: customer.id)
      customer
    end
  end

  def fetch_stripe_products
    [
      {
        id: 'monthly',
        name: 'Monthly Membership',
        price: 1599,
        interval: 'month',
        features: Membership::BENEFITS,
        popular: false,
        price_id: ENV.fetch('STRIPE_MONTHLY_PRICE_ID', 'price_monthly')
      },
      {
        id: 'quarterly',
        name: 'Quarterly Membership',
        price: 1299,
        interval: 'month',
        features: Membership::BENEFITS,
        popular: true,
        price_id: ENV.fetch('STRIPE_QUARTERLY_PRICE_ID', 'price_quarterly'),
        savings: '19%'
      },
      {
        id: 'yearly',
        name: 'Yearly Membership',
        price: 1099,
        interval: 'month',
        features: Membership::BENEFITS,
        popular: false,
        price_id: ENV.fetch('STRIPE_YEARLY_PRICE_ID', 'price_yearly'),
        savings: '31%'
      }
    ]
  end

end
