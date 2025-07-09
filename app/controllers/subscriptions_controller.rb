class SubscriptionsController < ApplicationController
  before_action :authenticate_user!
  protect_from_forgery with: :exception

  def create_checkout_session
    price_id = params[:price_id]
    
    # Define price IDs for each plan (these will be your Stripe Price IDs)
    price_ids = {
      'monthly' => ENV.fetch('STRIPE_MONTHLY_PRICE_ID', 'price_monthly'),
      'quarterly' => ENV.fetch('STRIPE_QUARTERLY_PRICE_ID', 'price_quarterly'),
      'yearly' => ENV.fetch('STRIPE_YEARLY_PRICE_ID', 'price_yearly')
    }
    
    unless price_ids.key?(price_id)
      redirect_to account_path(anchor: 'subscription'), alert: 'Invalid subscription plan'
      return
    end

    begin
      # Get or create Stripe customer
      customer = get_or_create_stripe_customer
      
      # Create Stripe checkout session
      session = Stripe::Checkout::Session.create({
        customer: customer.id,
        payment_method_types: ['card'],
        line_items: [{
          price: price_ids[price_id],
          quantity: 1,
        }],
        mode: 'subscription',
        success_url: account_url + '?subscription=success#subscription',
        cancel_url: account_url + '?subscription=cancelled#subscription',
        metadata: {
          user_id: current_user.id,
          plan: price_id
        }
      })

      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      redirect_to account_path(anchor: 'subscription'), alert: 'Payment processing error. Please try again.'
    end
  end

  def portal
    # Redirect to Stripe Customer Portal for subscription management
    return redirect_to account_path, alert: 'No active subscription found' unless current_user.stripe_customer_id

    begin
      session = Stripe::BillingPortal::Session.create({
        customer: current_user.stripe_customer_id,
        return_url: account_url
      })

      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe portal error: #{e.message}"
      redirect_to account_path, alert: 'Unable to access billing portal. Please try again.'
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
end