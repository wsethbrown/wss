module Presentations
  # Grants deck access for a paid Stripe Checkout session.
  #
  # ONE code path, called from two places, because relying on the webhook
  # alone left a real hole: the buyer is redirected back the instant Stripe
  # finishes, which can beat the webhook, and in local development the
  # webhook never arrives at all unless `stripe listen` is running. So the
  # return path fulfills synchronously and the webhook remains the backstop
  # for anyone who closes the tab.
  #
  # Idempotent by the existing (user, presentation) purchase check, so both
  # callers racing on the same session grant exactly one UserPresentation.
  class CheckoutFulfillment
    # Returns the UserPresentation (new or pre-existing), or nil when the
    # session isn't a paid deck purchase.
    def self.fulfill!(session, expected_user: nil)
      metadata = session.respond_to?(:metadata) ? session.metadata : session["metadata"]
      user_id = metadata && (metadata["user_id"] || metadata[:user_id])
      presentation_id = metadata && (metadata["presentation_id"] || metadata[:presentation_id])
      session_id = session.try(:id) || session["id"]

      unless user_id && presentation_id
        Rails.logger.info "Checkout #{session_id}: not a deck purchase (no user/presentation metadata); nothing to fulfill"
        return nil
      end

      payment_status = session.try(:payment_status) || session["payment_status"]
      if payment_status.present? && payment_status != "paid"
        Rails.logger.warn "Checkout #{session_id}: payment_status #{payment_status}, refusing to grant deck #{presentation_id}"
        return nil
      end

      # A tampered session_id on the return URL must never grant someone
      # else's purchase to the person holding the link.
      if expected_user && expected_user.id.to_s != user_id.to_s
        Rails.logger.warn "Checkout #{session_id}: session belongs to user #{user_id}, not #{expected_user.id}; refusing"
        return nil
      end

      user = User.find_by(id: user_id)
      presentation = Presentation.find_by(id: presentation_id)
      unless user && presentation
        Rails.logger.error "Checkout #{session_id}: user #{user_id} or presentation #{presentation_id} missing; cannot fulfill"
        return nil
      end

      existing = UserPresentation.find_by(user: user, presentation: presentation)
      if existing
        Rails.logger.info "Checkout #{session_id}: deck #{presentation.id} already granted to user #{user.id}; nothing to do"
        return existing
      end

      payment_intent_id = session.try(:payment_intent) || session["payment_intent"]
      amount_paid, intent_id = payment_details(payment_intent_id, presentation, session_id)

      purchase = UserPresentation.create!(
        user: user,
        presentation: presentation,
        purchase_type: "direct",
        purchase_price: amount_paid,
        stripe_payment_intent_id: intent_id,
        purchased_at: Time.current
      )
      Rails.logger.info "Checkout #{session_id}: deck #{presentation.id} granted to user #{user.id} for #{amount_paid} (purchase #{purchase.id})"
      purchase
    rescue ActiveRecord::RecordNotUnique
      # Webhook and return path landed together; the other one won.
      Rails.logger.info "Checkout #{session_id}: concurrent fulfillment won the race; deck already granted"
      UserPresentation.find_by(user_id: user_id, presentation_id: presentation_id)
    rescue => e
      Rails.logger.error "Checkout #{session_id} fulfillment failed for user #{user_id}, presentation #{presentation_id}: #{e.class}: #{e.message}"
      nil
    end

    # The charged amount, straight from Stripe when we can read it; the deck's
    # list price is the fallback so a Stripe hiccup never blocks access.
    def self.payment_details(payment_intent_id, presentation, session_id)
      return [ presentation.price, nil ] if payment_intent_id.blank?

      intent = Stripe::PaymentIntent.retrieve(payment_intent_id)
      amount = (intent.try(:amount) || intent["amount"]).to_i / 100.0
      [ amount, intent.try(:id) || intent["id"] ]
    rescue Stripe::StripeError => e
      Rails.logger.warn "Checkout #{session_id}: could not read payment intent #{payment_intent_id} (#{e.message}); recording list price"
      [ presentation.price, payment_intent_id ]
    end
    private_class_method :payment_details
  end
end
