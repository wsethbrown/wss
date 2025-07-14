class PresentationsController < ApplicationController
  before_action :set_presentation, only: [:show, :edit, :update, :destroy]

  def index
    # Use database presentations
    @presentations = Presentation.published.includes(:author)
    
    # Filter by search term
    if params[:search].present?
      @presentations = @presentations.search(params[:search])
    end

    # Filter by category
    if params[:category].present?
      @presentations = @presentations.by_category(params[:category])
    end

    # Filter by difficulty
    if params[:difficulty].present?
      @presentations = @presentations.by_difficulty(params[:difficulty])
    end

    # Sort
    case params[:sort]
    when 'newest'
      @presentations = @presentations.recent
    when 'rating'
      @presentations = @presentations.popular
    when 'price_low'
      @presentations = @presentations.order(:price)
    when 'price_high'
      @presentations = @presentations.order(price: :desc)
    else # 'popular' - default
      @presentations = @presentations.popular
    end
  end

  def show
    @presentation = Presentation.find(params[:id])
  end

  def new
    @presentation = Presentation.new
    authorize @presentation
  end

  def create
    @presentation = current_user.presentations.build(presentation_params)
    authorize @presentation

    if @presentation.save
      redirect_to @presentation, notice: 'Presentation was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @presentation
  end

  def update
    authorize @presentation

    if @presentation.update(presentation_params)
      redirect_to @presentation, notice: 'Presentation was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @presentation

    @presentation.destroy
    redirect_to presentations_url, notice: 'Presentation was successfully deleted.'
  end

  def purchase_options
    # Show purchase options modal/page
    @presentation = Presentation.find(params[:id])
    render :purchase_options
  end

  def purchase
    Rails.logger.info "=== PURCHASE ACTION CALLED ==="
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "Purchase type: #{params[:purchase_type]}"
    Rails.logger.info "User signed in: #{user_signed_in?}"
    Rails.logger.info "Current user: #{current_user&.email}"
    
    @presentation = Presentation.find(params[:id])
    purchase_type = params[:purchase_type] # 'credit' or 'direct'
    
    if purchase_type == 'credit'
      purchase_with_credit
    elsif purchase_type == 'direct'
      # Temporarily disable Stripe - just simulate successful purchase
      simulate_direct_purchase
    else
      redirect_to presentation_path(params[:id]), alert: 'Invalid purchase type'
    end
  end

  private

  def set_presentation
    @presentation = Presentation.find(params[:id])
  end

  def presentation_params
    params.require(:presentation).permit(:title, :description, :content, :price, :category)
  end

  def simulate_direct_purchase
    unless user_signed_in?
      redirect_to auth_path, alert: 'Please sign in to purchase presentations'
      return
    end

    # Check if already purchased
    if already_purchased?
      redirect_to presentation_path(params[:id]), notice: 'You already own this presentation'
      return
    end

    # Simulate successful direct purchase
    UserPresentation.create!(
      user: current_user,
      presentation_id: params[:id],
      purchase_type: 'direct',
      purchased_at: Time.current
    )
    
    redirect_to presentation_path(params[:id]) + "?purchase=success", notice: 'Presentation purchased successfully! (Simulated - no payment processed)'
  end

  def purchase_with_credit
    unless user_signed_in?
      redirect_to auth_path, alert: 'Please sign in to purchase presentations'
      return
    end

    unless current_user.has_active_subscription?
      redirect_to presentation_path(params[:id]), alert: 'Active subscription required to purchase with credits'
      return
    end

    credit_cost = 1 # Presentations cost 1 credit
    unless current_user.has_sufficient_credits?(credit_cost)
      redirect_to presentation_path(params[:id]), alert: 'Insufficient credits. You need 1 credit to purchase this presentation.'
      return
    end

    # Check if already purchased
    if already_purchased?
      redirect_to presentation_path(params[:id]), notice: 'You already own this presentation'
      return
    end

    # Process credit purchase
    if current_user.deduct_credits(credit_cost)
      # Create user_presentation record
      UserPresentation.create!(
        user: current_user,
        presentation_id: params[:id],
        purchase_type: 'credit',
        purchased_at: Time.current
      )
      
      redirect_to presentation_path(params[:id]), notice: 'Presentation purchased successfully with credit!'
    else
      redirect_to presentation_path(params[:id]), alert: 'Failed to process credit purchase'
    end
  end

  def purchase_with_stripe
    unless user_signed_in?
      redirect_to auth_path, alert: 'Please sign in to purchase presentations'
      return
    end

    # Check if already purchased
    if already_purchased?
      redirect_to presentation_path(params[:id]), notice: 'You already own this presentation'
      return
    end

    begin
      # Get or create Stripe customer
      customer = get_or_create_stripe_customer

      # Create Stripe checkout session for one-time payment
      session = Stripe::Checkout::Session.create({
        customer: customer.id,
        payment_method_types: ['card'],
        line_items: [{
          price_data: {
            currency: 'usd',
            product_data: {
              name: @presentation.title,
              description: @presentation.description
            },
            unit_amount: (@presentation.price * 100).to_i # Convert to cents
          },
          quantity: 1
        }],
        mode: 'payment', # One-time payment, not subscription
        success_url: presentation_url(params[:id]) + "?purchase=success",
        cancel_url: presentation_url(params[:id]) + "?purchase=cancelled",
        metadata: {
          user_id: current_user.id,
          presentation_id: params[:id],
          purchase_type: 'direct'
        }
      })

      redirect_to session.url, allow_other_host: true
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe error: #{e.message}"
      redirect_to presentation_path(params[:id]), alert: 'Payment processing error. Please try again.'
    end
  end

  def already_purchased?
    current_user&.user_presentations&.exists?(presentation_id: params[:id])
  end

  def get_or_create_stripe_customer
    if current_user.stripe_customer_id.present?
      Stripe::Customer.retrieve(current_user.stripe_customer_id)
    else
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
end
