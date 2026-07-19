class Presentations::PurchasesController < ApplicationController
  include ActivityLogger

  before_action :authenticate_user!
  before_action :set_presentation
  before_action :check_already_purchased

  # The single purchase flow for every deck:
  #   - free decks    → claimed instantly, no payment involved
  #   - credit        → spends 1 credit (requires an active subscription)
  #   - direct        → Stripe Checkout; access granted on return (verified with
  #                     Stripe) and by the webhook as backstop, both idempotent
  def new
    @can_use_credit = can_use_credit?
  end

  def create
    if @presentation.free?
      handle_free_claim
      return
    end

    case params[:purchase_method]
    when "credit"
      handle_credit_purchase
    when "direct"
      handle_direct_purchase
    else
      redirect_to @presentation, alert: "Choose a purchase method to continue"
    end
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:presentation_id])
    # Drafts are not for sale/download: 404 for non-admins (see PresentationsController).
    raise ActiveRecord::RecordNotFound unless @presentation.published? || current_user&.admin?
  end

  def check_already_purchased
    if @presentation.purchased_by?(current_user)
      redirect_to @presentation, notice: "This deck is already in your library"
    end
  end

  # Credits are a membership benefit: they can only be spent while the
  # subscription that granted them is active (matching User#can_access_presentation?,
  # which gates credit-purchased content on an active subscription).
  def can_use_credit?
    current_user.subscription_active? && current_user.credits > 0
  end

  def handle_free_claim
    current_user.user_presentations.create!(
      presentation: @presentation,
      purchase_type: "direct",
      purchase_price: 0,
      purchased_at: Time.current
    )
    log_activity(:presentation_purchased, @presentation, { purchase_type: "free", price: 0 })
    redirect_to @presentation, notice: "Added to your library. This deck is free."
  end

  def handle_credit_purchase
    unless current_user.subscription_active?
      redirect_to new_presentation_purchase_path(@presentation),
                  alert: "An active membership is required to spend credits"
      return
    end

    unless current_user.credits > 0
      redirect_to new_presentation_purchase_path(@presentation), alert: "Insufficient credits"
      return
    end

    if CreditTransaction.use_credit(current_user, @presentation)
      log_activity(:presentation_purchased, @presentation, { purchase_type: "credit", price: 1 })
      log_activity(:credits_used, @presentation, { amount: 1 })
      redirect_to @presentation, notice: "Deck unlocked with 1 credit."
    else
      redirect_to new_presentation_purchase_path(@presentation), alert: "Failed to complete purchase"
    end
  end

  def handle_direct_purchase
    session = Stripe::Checkout::Session.create({
      customer: current_user.stripe_customer_id || create_stripe_customer.id,
      line_items: [ {
        price_data: {
          currency: "usd",
          product_data: {
            name: @presentation.title,
            description: @presentation.excerpt(200),
            metadata: { presentation_id: @presentation.id }
          },
          unit_amount: @presentation.stripe_amount
        },
        quantity: 1
      } ],
      # No payment_method_types: omitting it lets Stripe Checkout offer every
      # method enabled in the dashboard (cards, Apple Pay, Google Pay, Link, ...).
      mode: "payment",
      # session_id lets the return path verify the payment with Stripe and
      # grant access immediately, instead of waiting on the webhook (which
      # can lag, and never arrives in local dev without `stripe listen`).
      # APPENDED AS A STRING ON PURPOSE: passing it through the URL helper
      # percent-encodes the braces, Stripe then never substitutes the real
      # id and the return path can't look the session up. Keep it literal.
      success_url: "#{presentation_url(@presentation, purchase: 'success')}&session_id={CHECKOUT_SESSION_ID}",
      cancel_url: new_presentation_purchase_url(@presentation),
      metadata: {
        user_id: current_user.id,
        presentation_id: @presentation.id
      }
    })

    redirect_to session.url, allow_other_host: true
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe error creating checkout for presentation #{@presentation.id}: #{e.message}"
    redirect_to new_presentation_purchase_path(@presentation),
                alert: "Payment processing error. Please try again."
  end

  def create_stripe_customer
    customer = Stripe::Customer.create({
      email: current_user.email,
      name: current_user.full_name,
      metadata: { user_id: current_user.id }
    })

    current_user.update!(stripe_customer_id: customer.id)
    customer
  end
end
