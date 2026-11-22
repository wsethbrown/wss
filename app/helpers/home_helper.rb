# Shaping for the homepage's plan cards. Prices come from SubscriptionProducts
# (live from Stripe, a fallback offline) as per-month cents, so savings are
# worked out from those prices rather than from a stored label.
module HomeHelper
  # Same wording as the billing line on /membership (shared/_membership_pricing).
  PLAN_BILLING = { "monthly" => "billed monthly", "quarterly" => "billed quarterly", "yearly" => "billed annually" }.freeze

  def plan_billing_line(product)
    PLAN_BILLING.fetch(product[:id].to_s, PLAN_BILLING["monthly"])
  end

  # Whole-percent saving of a plan's per-month price against the monthly
  # plan's, or nil when there is no monthly plan, this is it, or it is not
  # cheaper. Logs a warning when Stripe's "savings" label disagrees, since
  # /membership shows that label.
  def plan_savings_percent(product, products)
    monthly = products.find { |p| p[:id].to_s == "monthly" }
    return nil if monthly.nil? || product[:id].to_s == "monthly"

    base, price = monthly[:price].to_i, product[:price].to_i
    return nil unless base.positive? && price.positive? && price < base

    percent = ((base - price) * 100.0 / base).round
    return nil unless percent.positive?

    if product[:savings].present? && product[:savings].to_s.delete("%").strip != percent.to_s
      Rails.logger.warn "Home pricing: plan #{product[:id]} savings label #{product[:savings]} differs from computed #{percent}%"
    end
    percent
  end
end
