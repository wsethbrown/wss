# Estimated subscription revenue for the admin dashboards. This is an ESTIMATE:
# current active subscribers per plan times each plan's live monthly-equivalent
# price (from SubscriptionProducts). It is monthly recurring revenue (MRR), not
# actual cash collected, which would require reconciling Stripe invoices.
module SubscriptionRevenue
  module_function

  # MRR in dollars (Float).
  def monthly_recurring
    prices = SubscriptionProducts.monthly_cents_by_plan
    cents = User.where(subscription_status: "active")
                .where.not(subscription_plan: [ nil, "" ])
                .group(:subscription_plan)
                .count
                .sum { |plan, count| prices[plan.to_s].to_i * count }
    (cents / 100.0).round(2)
  end
end
