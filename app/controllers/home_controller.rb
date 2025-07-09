class HomeController < ApplicationController
  def index
    # Fetch Stripe products for pricing display
    @stripe_products = fetch_stripe_products
  end

  private

  def calculate_monthly_price(price, interval)
    case interval
    when 'year'
      (price / 12.0).round
    when 'quarter', '3_months'
      (price / 3.0).round
    else
      price
    end
  end

  def fetch_stripe_products
    return fallback_products unless Stripe.api_key.present?

    begin
      # Cache the products to avoid repeated API calls
      Rails.cache.fetch('stripe_products', expires_in: 1.hour) do
        products = []

        # Fetch monthly product
        if ENV['STRIPE_MONTHLY_PRICE_ID'].present?
          begin
            monthly_price = Stripe::Price.retrieve(ENV['STRIPE_MONTHLY_PRICE_ID'], expand: ['product'])
            if monthly_price && monthly_price.product
              products << {
                id: 'monthly',
                name: monthly_price.product.name || 'Monthly Membership',
                price: monthly_price.unit_amount,
                interval: 'month',
                display_interval: 'month',
                features: monthly_price.product.metadata.to_h.fetch('features', '1 credit per month,Access to all society features,Monthly whiskey recommendations').split(',').map(&:strip),
                popular: monthly_price.product.metadata.to_h.fetch('popular', 'false') == 'true',
                price_id: monthly_price.id
              }
            end
          rescue => e
            Rails.logger.error "Error fetching monthly price: #{e.message}"
          end
        end

        # Fetch quarterly product
        if ENV['STRIPE_QUARTERLY_PRICE_ID'].present?
          begin
            quarterly_price = Stripe::Price.retrieve(ENV['STRIPE_QUARTERLY_PRICE_ID'], expand: ['product'])
            if quarterly_price && quarterly_price.product
              # Calculate monthly equivalent for quarterly
              quarterly_interval = quarterly_price.recurring&.interval || 'month'
              quarterly_interval_count = quarterly_price.recurring&.interval_count || 1
              monthly_equivalent = if quarterly_interval == 'month' && quarterly_interval_count == 3
                (quarterly_price.unit_amount / 3.0).round
              else
                quarterly_price.unit_amount
              end

              products << {
                id: 'quarterly',
                name: quarterly_price.product.name || 'Quarterly Membership',
                price: monthly_equivalent,
                interval: 'month',
                display_interval: 'month',
                features: quarterly_price.product.metadata.to_h.fetch('features', 'Everything in Monthly,Priority support,Early access to new features').split(',').map(&:strip).reject { |f| f.include?('%') || f.downcase.include?('save') || f.downcase.include?('savings') },
                popular: quarterly_price.product.metadata.to_h.fetch('popular', 'true') == 'true',
                price_id: quarterly_price.id,
                savings: quarterly_price.product.metadata.to_h.fetch('savings', '19%')
              }
            end
          rescue => e
            Rails.logger.error "Error fetching quarterly price: #{e.message}"
          end
        end

        # Fetch yearly product
        if ENV['STRIPE_YEARLY_PRICE_ID'].present?
          begin
            yearly_price = Stripe::Price.retrieve(ENV['STRIPE_YEARLY_PRICE_ID'], expand: ['product'])
            if yearly_price && yearly_price.product
              # Calculate monthly equivalent for yearly
              yearly_interval = yearly_price.recurring&.interval || 'year'
              monthly_equivalent = if yearly_interval == 'year'
                (yearly_price.unit_amount / 12.0).round
              else
                yearly_price.unit_amount
              end

              products << {
                id: 'yearly',
                name: yearly_price.product.name || 'Yearly Membership',
                price: monthly_equivalent,
                interval: 'month',
                display_interval: 'month',
                features: yearly_price.product.metadata.to_h.fetch('features', 'Everything in Quarterly,VIP access to exclusive events,Personal whisky curator').split(',').map(&:strip).reject { |f| f.include?('%') || f.downcase.include?('save') || f.downcase.include?('savings') },
                popular: yearly_price.product.metadata.to_h.fetch('popular', 'false') == 'true',
                price_id: yearly_price.id,
                savings: yearly_price.product.metadata.to_h.fetch('savings', '31%')
              }
            end
          rescue => e
            Rails.logger.error "Error fetching yearly price: #{e.message}"
          end
        end

        # Sort products to ensure consistent order: monthly, quarterly, yearly
        sorted_products = products.sort_by do |p|
          case p[:id]
          when 'monthly' then 0
          when 'quarterly' then 1
          when 'yearly' then 2
          else 3
          end
        end

        # Return default products if we got no products from Stripe
        if sorted_products.empty?
          fallback_products
        else
          sorted_products
        end
      end
    rescue => e
      Rails.logger.error "Error fetching Stripe products: #{e.message}"
      # Return default products if Stripe is unavailable
      fallback_products
    end
  end

  def fallback_products
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
