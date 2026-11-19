class StripeEvent < ApplicationRecord
  # A claim with no processed_at is in flight. If its handler never finished
  # (deploy or kill mid-request), Stripe's redelivery may re-claim it after this.
  STALE_CLAIM_AFTER = 10.minutes

  validates :stripe_event_id, presence: true, uniqueness: true

  # Claims an event id for processing. Returns true if this caller won the claim
  # (should process), false if the event is processed or another claim on it is
  # still in flight. A claim left unprocessed for STALE_CLAIM_AFTER is taken
  # over atomically (only one redelivery can win the UPDATE).
  # Handles both the validation-caught duplicate (RecordInvalid) and the racy
  # DB-level duplicate (RecordNotUnique).
  def self.claim(event_id, event_type)
    create!(stripe_event_id: event_id, event_type: event_type)
    true
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    reclaim_stale(event_id)
  end

  def self.reclaim_stale(event_id)
    now = Time.current
    won = where(stripe_event_id: event_id, processed_at: nil)
          .where(updated_at: ...(now - STALE_CLAIM_AFTER))
          .update_all(updated_at: now) == 1
    Rails.logger.warn "Stripe event #{event_id}: re-claimed a claim left unprocessed for over #{STALE_CLAIM_AFTER.inspect}" if won
    won
  end
  private_class_method :reclaim_stale

  def self.processed?(event_id)
    where(stripe_event_id: event_id).where.not(processed_at: nil).exists?
  end

  # Marks a claimed event as fully handled; it will never be processed again.
  def self.mark_processed(event_id)
    where(stripe_event_id: event_id).update_all(processed_at: Time.current, updated_at: Time.current)
  end

  # Releases a claim so a failed event can be retried by Stripe.
  def self.release(event_id)
    where(stripe_event_id: event_id).delete_all
  end
end
