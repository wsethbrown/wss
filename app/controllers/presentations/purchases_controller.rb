class Presentations::PurchasesController < ApplicationController
  include ActivityLogger
  
  before_action :authenticate_user!
  before_action :set_presentation
  before_action :check_already_purchased, only: [:new, :create]
  
  def new
    # Show purchase options (credit or direct payment)
    @has_credits = current_user.credits > 0
    @user_subscription_active = current_user.subscription_active?
  end
  
  def create
    purchase_method = params[:purchase_method]
    
    case purchase_method
    when 'credit'
      handle_credit_purchase
    when 'direct'
      handle_direct_purchase
    else
      redirect_to @presentation, alert: 'Invalid purchase method'
    end
  end
  
  private
  
  def set_presentation
    @presentation = Presentation.find(params[:presentation_id])
  end
  
  def check_already_purchased
    if @presentation.purchased_by?(current_user)
      redirect_to @presentation, notice: 'You already have access to this presentation'
    end
  end
  
  def handle_credit_purchase
    if current_user.credits < 1
      redirect_to new_presentation_purchase_path(@presentation), alert: 'Insufficient credits'
      return
    end
    
    if CreditTransaction.use_credit(current_user, @presentation)
      log_activity(:presentation_purchased, @presentation, { purchase_type: 'credit', price: 1 })
      log_activity(:credits_used, @presentation, { amount: 1 })
      redirect_to @presentation, notice: 'Presentation purchased successfully with credit!'
    else
      redirect_to new_presentation_purchase_path(@presentation), alert: 'Failed to complete purchase'
    end
  end
  
  def handle_direct_purchase
    begin
      # Create Stripe checkout session
      session = Stripe::Checkout::Session.create({
        customer: current_user.stripe_customer_id || create_stripe_customer.id,
        payment_method_types: ['card'],
        line_items: [{
          price_data: {
            currency: 'usd',
            product_data: {
              name: @presentation.title,
              description: @presentation.excerpt(200),
              metadata: {
                presentation_id: @presentation.id
              }
            },
            unit_amount: @presentation.stripe_amount
          },
          quantity: 1
        }],
        mode: 'payment',
        success_url: presentation_url(@presentation, purchase: 'success'),
        cancel_url: new_presentation_purchase_url(@presentation),
        metadata: {
          user_id: current_user.id,
          presentation_id: @presentation.id
        }
      })
      
      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      redirect_to new_presentation_purchase_path(@presentation), alert: 'Payment processing error. Please try again.'
    end
  end
  
  def create_stripe_customer
    customer = Stripe::Customer.create({
      email: current_user.email,
      name: current_user.full_name,
      metadata: {
        user_id: current_user.id
      }
    })
    
    current_user.update!(stripe_customer_id: customer.id)
    customer
  end
end