# The single source of truth for what a WSS membership includes, and what a
# free account already gets.
#
# The tiers (monthly/quarterly/yearly) all unlock the SAME thing — they
# differ only in price and billing cadence — so BENEFITS is one list, not
# three, and no tier "adds" anything the others lack.
#
# The paid/free split is deliberate: reviews are the sticky, everyday reason
# to have an account, so the whole tasting record — joining societies,
# writing and favoriting reviews, buying a deck outright — stays FREE.
# Membership is for the things that cost us or that power users want:
# a monthly deck credit and the ability to start and run a society.
#
# Keeping the lists here stops invented perks from creeping back into the
# pricing copy; Stripe metadata may still override the per-tier features.
module Membership
  # What paid membership unlocks beyond a free account.
  BENEFITS = [
    "One deck credit every month — unlock any narrative tasting deck",
    "Create and run your own society — host tasting nights, manage members and events",
    "Keep your credit-unlocked decks for as long as you're a member"
  ].freeze

  # What any free account can already do (no membership required).
  FREE = [
    "Join any public society",
    "Write reviews, rate and favorite bottles",
    "Follow the tasters and societies whose picks you trust",
    "Buy any deck outright to own it forever"
  ].freeze
end
