class StripeEvent < ApplicationRecord
  validates :stripe_event_id, presence: true, uniqueness: true

  # Claims an event id for processing. Returns true if this caller won the claim
  # (should process), false if the event was already claimed/processed.
  def self.claim(event_id, event_type)
    create!(stripe_event_id: event_id, event_type: event_type)
    true
  rescue ActiveRecord::RecordNotUnique
    false
  end

  # Releases a claim so a failed event can be retried by Stripe.
  def self.release(event_id)
    where(stripe_event_id: event_id).delete_all
  end
end
