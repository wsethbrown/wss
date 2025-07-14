class SubscriptionsController < ApplicationController
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

      # Create Stripe checkout session
      session = Stripe::Checkout::Session.create({
        customer: customer.id,
        payment_method_types: [ "card" ],
        line_items: [ {
          price: price_ids[price_id],
          quantity: 1
        } ],
        mode: "subscription",
        success_url: presentations_url + "?subscription=success",
        cancel_url: account_url + "?subscription=cancelled#subscription",
        metadata: {
          user_id: current_user.id,
          plan: price_id
        }
      })

      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      redirect_to account_path(anchor: "subscription"), alert: "Payment processing error. Please try again."
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

  private

  def get_or_create_stripe_customer
    if current_user.stripe_customer_id.present?
      # Return existing customer
      Stripe::Customer.retrieve(current_user.stripe_customer_id)
    else
      # Create new customer
      customer = Stripe::Customer.create({
        email: current_user.email,
        name: current_user.full_name,
        metadata: {
          user_id: current_user.id
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
        features: ['1 credit per month', 'Access to all society features', 'Monthly whiskey recommendations'],
        popular: false,
        price_id: ENV.fetch('STRIPE_MONTHLY_PRICE_ID', 'price_monthly')
      },
      {
        id: 'quarterly',
        name: 'Quarterly Membership',
        price: 1299,
        interval: 'month',
        features: ['Everything in Monthly', 'Priority support', 'Early access to new features'],
        popular: true,
        price_id: ENV.fetch('STRIPE_QUARTERLY_PRICE_ID', 'price_quarterly'),
        savings: '19%'
      },
      {
        id: 'yearly',
        name: 'Yearly Membership',
        price: 1099,
        interval: 'month',
        features: ['Everything in Quarterly', 'VIP access to exclusive events', 'Personal whisky curator'],
        popular: false,
        price_id: ENV.fetch('STRIPE_YEARLY_PRICE_ID', 'price_yearly'),
        savings: '31%'
      }
    ]
  end
end
