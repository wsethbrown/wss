# The single source of truth for what a WSS membership includes.
#
# Every tier — monthly, quarterly, yearly — unlocks exactly the same thing;
# they differ only in price and billing cadence. So there is ONE benefits
# list, not three, and no tier "adds" anything the others lack. Keeping it
# here stops invented perks (priority support, VIP events, a personal
# curator — none of which exist) from creeping back into the pricing copy.
#
# Stripe product metadata may still override the per-tier `features` string
# if a real per-tier difference is ever introduced; until then this is the
# honest default everywhere plans are shown.
module Membership
  BENEFITS = [
    "One deck credit every month",
    "Every narrative tasting deck to spend it on",
    "Full society access — create, join, and host tasting nights",
    "The complete tasting record — reviews, ratings, and flavor profiles",
    "Keep your decks for as long as you're a member"
  ].freeze
end
