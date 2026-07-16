# Single source of truth for the membership products (monthly/quarterly/yearly)
# and their LIVE monthly-equivalent prices. The homepage/membership pricing cards
# AND admin revenue both read this, so a price is never hardcoded in two places.
# Live values are fetched from Stripe (1h cache); tests and a keyless/unreachable
# Stripe fall back to `fallback`.
module SubscriptionProducts
  module_function

  def all
    return fallback if Rails.env.test?
    return fallback unless Stripe.api_key.present?

    begin
      Rails.cache.fetch("stripe_products", expires_in: 1.hour) do
        products = []

        if ENV["STRIPE_MONTHLY_PRICE_ID"].present?
          begin
            monthly_price = Stripe::Price.retrieve({ id: ENV["STRIPE_MONTHLY_PRICE_ID"], expand: ["product"] })
            if monthly_price && monthly_price.product
              products << {
                id: "monthly",
                name: monthly_price.product.name || "Monthly Membership",
                price: monthly_price.unit_amount,
                interval: "month",
                display_interval: "month",
                features: (monthly_price.product.metadata.to_h["features"]&.split(",")&.map(&:strip) || Membership::BENEFITS),
                popular: monthly_price.product.metadata.to_h.fetch("popular", "false") == "true",
                price_id: monthly_price.id
              }
            end
          rescue => e
            Rails.logger.error "Error fetching monthly price: #{e.message}"
          end
        end

        if ENV["STRIPE_QUARTERLY_PRICE_ID"].present?
          begin
            quarterly_price = Stripe::Price.retrieve({ id: ENV["STRIPE_QUARTERLY_PRICE_ID"], expand: ["product"] })
            if quarterly_price && quarterly_price.product
              quarterly_interval = quarterly_price.recurring&.interval || "month"
              quarterly_interval_count = quarterly_price.recurring&.interval_count || 1
              monthly_equivalent = if quarterly_interval == "month" && quarterly_interval_count == 3
                (quarterly_price.unit_amount / 3.0).round
              else
                quarterly_price.unit_amount
              end

              products << {
                id: "quarterly",
                name: quarterly_price.product.name || "Quarterly Membership",
                price: monthly_equivalent,
                interval: "month",
                display_interval: "month",
                features: (quarterly_price.product.metadata.to_h["features"]&.split(",")&.map(&:strip) || Membership::BENEFITS).reject { |f| f.include?("%") || f.downcase.include?("save") || f.downcase.include?("savings") },
                popular: quarterly_price.product.metadata.to_h.fetch("popular", "false") == "true",
                price_id: quarterly_price.id,
                savings: quarterly_price.product.metadata.to_h.fetch("savings", "19%")
              }
            end
          rescue => e
            Rails.logger.error "Error fetching quarterly price: #{e.message}"
          end
        end

        if ENV["STRIPE_YEARLY_PRICE_ID"].present?
          begin
            yearly_price = Stripe::Price.retrieve({ id: ENV["STRIPE_YEARLY_PRICE_ID"], expand: ["product"] })
            if yearly_price && yearly_price.product
              yearly_interval = yearly_price.recurring&.interval || "year"
              monthly_equivalent = if yearly_interval == "year"
                (yearly_price.unit_amount / 12.0).round
              else
                yearly_price.unit_amount
              end

              products << {
                id: "yearly",
                name: yearly_price.product.name || "Yearly Membership",
                price: monthly_equivalent,
                interval: "month",
                display_interval: "month",
                features: (yearly_price.product.metadata.to_h["features"]&.split(",")&.map(&:strip) || Membership::BENEFITS).reject { |f| f.include?("%") || f.downcase.include?("save") || f.downcase.include?("savings") },
                popular: yearly_price.product.metadata.to_h.fetch("popular", "true") == "true",
                price_id: yearly_price.id,
                savings: yearly_price.product.metadata.to_h.fetch("savings", "31%")
              }
            end
          rescue => e
            Rails.logger.error "Error fetching yearly price: #{e.message}"
          end
        end

        sorted = products.sort_by do |p|
          case p[:id]
          when "monthly" then 0
          when "quarterly" then 1
          when "yearly" then 2
          else 3
          end
        end

        sorted.empty? ? fallback : sorted
      end
    rescue => e
      Rails.logger.error "Error fetching Stripe products: #{e.message}"
      fallback
    end
  end

  # plan id ("monthly"/"quarterly"/"yearly") => monthly-equivalent price in cents.
  # Founding plans are included so admin MRR counts them at their real rates.
  def monthly_cents_by_plan
    prices = all.each_with_object({}) { |p, h| h[p[:id].to_s] = p[:price].to_i }
    founding.each { |p| prices[p[:id].to_s] = p[:price].to_i }
    prices
  end

  # The two Founding Member offers (first 50, kept while never cancelling):
  # the $5/mo society-only plan and the $5-off full monthly. Live amounts from
  # Stripe when the env price ids exist; fallback display values otherwise.
  def founding
    return founding_fallback if Rails.env.test?
    return founding_fallback unless Stripe.api_key.present?

    Rails.cache.fetch("stripe_founding_products", expires_in: 1.hour) do
      founding_fallback.map do |offer|
        env_id = offer[:id] == "founding_society" ? "STRIPE_FOUNDING_SOCIETY_PRICE_ID" : "STRIPE_FOUNDING_MONTHLY_PRICE_ID"
        next offer if ENV[env_id].blank?

        begin
          price = Stripe::Price.retrieve({ id: ENV[env_id] })
          offer.merge(price: price.unit_amount, price_id: price.id)
        rescue => e
          Rails.logger.error "Error fetching founding price #{env_id}: #{e.message}"
          offer
        end
      end
    end
  rescue => e
    Rails.logger.error "Error fetching founding products: #{e.message}"
    founding_fallback
  end

  def founding_fallback
    [
      {
        id: "founding_society",
        name: "Founding Society",
        price: 500,
        interval: "month",
        price_id: ENV.fetch("STRIPE_FOUNDING_SOCIETY_PRICE_ID", "price_founding_society")
      },
      {
        id: "founding_monthly",
        name: "Founding Monthly",
        price: 1099,
        interval: "month",
        price_id: ENV.fetch("STRIPE_FOUNDING_MONTHLY_PRICE_ID", "price_founding_monthly")
      }
    ]
  end

  def fallback
    [
      {
        id: "monthly",
        name: "Monthly Membership",
        price: 1599,
        interval: "month",
        features: Membership::BENEFITS,
        popular: false,
        price_id: ENV.fetch("STRIPE_MONTHLY_PRICE_ID", "price_monthly")
      },
      {
        id: "quarterly",
        name: "Quarterly Membership",
        price: 1299,
        interval: "month",
        features: Membership::BENEFITS,
        popular: false,
        price_id: ENV.fetch("STRIPE_QUARTERLY_PRICE_ID", "price_quarterly"),
        savings: "19%"
      },
      {
        id: "yearly",
        name: "Yearly Membership",
        price: 1099,
        interval: "month",
        features: Membership::BENEFITS,
        popular: true,
        price_id: ENV.fetch("STRIPE_YEARLY_PRICE_ID", "price_yearly"),
        savings: "31%"
      }
    ]
  end
end
