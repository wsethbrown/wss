module MailingList
  # The "tell me when a new deck is published" list (DeckNewsController, the
  # form in shared/_deck_news_form). Double opt-in:
  #
  #   request     -> creates or refreshes an unconfirmed MailingListSubscriber
  #                  and emails a confirm link (raw token in the link, only its
  #                  HMAC digest stored, EXPIRY).
  #   confirm     -> marks the row confirmed. Called from a POST only: opening
  #                  the emailed link shows a button, so mail scanners that
  #                  follow links confirm no one.
  #   unsubscribe -> a signed, single-purpose token (same pattern as
  #                  EventMutesController) sets unsubscribed_at.
  #
  # Privacy: the answer to a request never depends on whether the address is
  # already on the list, and no log line carries an address or a token (rows
  # are named by id).
  class SignupService
    EXPIRY = 7.days
    SOURCES = %w[library deck].freeze
    UNSUBSCRIBE_PURPOSE = "mailing_list_unsubscribe".freeze

    REQUEST_MESSAGE = "Check your email for a link to confirm.".freeze
    INVALID_EMAIL_MESSAGE = "Please enter a valid email address.".freeze

    Result = Struct.new(:success, :message, keyword_init: true) do
      def success?
        success
      end
    end

    # status: :confirmed (just now), :already_confirmed (no change) or :invalid.
    Confirmation = Struct.new(:status, :subscriber, keyword_init: true) do
      def confirmed? = status == :confirmed
      def already_confirmed? = status == :already_confirmed
      def invalid? = status == :invalid
    end

    # --- Request ------------------------------------------------------------

    def self.request(email, source: nil)
      email = email.to_s.strip.downcase
      source = SOURCES.include?(source.to_s) ? source.to_s : "other"

      unless email.length <= 254 && email.match?(URI::MailTo::EMAIL_REGEXP)
        Rails.logger.warn "Deck news request refused: invalid email (source #{source})"
        return Result.new(success: false, message: INVALID_EMAIL_MESSAGE)
      end

      subscriber = MailingListSubscriber.find_by(email: email)
      if subscriber&.active?
        # Same answer as a new request, so the form cannot be used to learn
        # who is on the list.
        Rails.logger.info "Deck news request: subscriber #{subscriber.id} already confirmed, nothing sent (source #{source})"
        return Result.new(success: true, message: REQUEST_MESSAGE)
      end

      kind = if subscriber.nil? then "new"
      elsif subscriber.unsubscribed_at then "repeat after unsubscribing"
      else "repeat"
      end
      raw = SecureRandom.urlsafe_base64(32)
      subscriber ||= MailingListSubscriber.new(email: email)
      subscriber.update!(confirmation_token_digest: digest(raw), confirmation_sent_at: Time.current,
                         confirmed_at: nil, unsubscribed_at: nil, source: source)
      Rails.logger.info "Deck news request: subscriber #{subscriber.id} (#{kind}), source #{source}"

      MailingListMailer.confirmation(subscriber, raw).deliver_later
      Rails.logger.info "Deck news confirmation email enqueued for subscriber #{subscriber.id}"
      Result.new(success: true, message: REQUEST_MESSAGE)
    rescue ActiveRecord::RecordNotUnique
      # Two requests for one new address at the same moment: the other one
      # created the row and sends the mail.
      Rails.logger.info "Deck news request: a simultaneous request for the same address won; nothing sent here (source #{source})"
      Result.new(success: true, message: REQUEST_MESSAGE)
    end

    # --- Confirm ------------------------------------------------------------

    # True when the link would confirm or has already confirmed. Reads only;
    # the confirm page (GET) uses it.
    def self.pending?(raw_token)
      find_for_confirmation(raw_token).present?
    end

    def self.confirm(raw_token)
      subscriber = find_for_confirmation(raw_token)
      unless subscriber
        Rails.logger.warn "Deck news confirm refused: invalid or expired token"
        return Confirmation.new(status: :invalid)
      end

      if subscriber.active?
        Rails.logger.info "Deck news confirm: subscriber #{subscriber.id} already confirmed, no change"
        return Confirmation.new(status: :already_confirmed, subscriber: subscriber)
      end

      subscriber.update!(confirmed_at: Time.current)
      Rails.logger.info "Deck news confirmed: subscriber #{subscriber.id} (source #{subscriber.source})"
      Confirmation.new(status: :confirmed, subscriber: subscriber)
    end

    # --- Unsubscribe --------------------------------------------------------

    def self.verifier
      Rails.application.message_verifier(:mailing_list_unsubscribe)
    end

    # No expiry: the link at the foot of an old email must keep working. It
    # can only ever turn these emails off for its own row.
    def self.unsubscribe_token_for(subscriber)
      verifier.generate({ "subscriber_id" => subscriber.id, "purpose" => UNSUBSCRIBE_PURPOSE })
    end

    # The row a signed unsubscribe token names, or nil. Reads only.
    def self.subscriber_for_unsubscribe(token)
      data = verifier.verify(token.to_s)
      raise ActiveSupport::MessageVerifier::InvalidSignature unless data.is_a?(Hash) && data["purpose"] == UNSUBSCRIBE_PURPOSE

      MailingListSubscriber.find(data["subscriber_id"])
    rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound => e
      # Forged token or a since-deleted row; never log the token.
      Rails.logger.warn "Deck news unsubscribe refused: #{e.class}"
      nil
    end

    # Sets unsubscribed_at (once) and kills any unused confirm link. Returns
    # the row, or nil when the token is not valid.
    def self.unsubscribe(token)
      subscriber = subscriber_for_unsubscribe(token)
      return nil unless subscriber

      if subscriber.unsubscribed_at
        Rails.logger.info "Deck news unsubscribe: subscriber #{subscriber.id} already unsubscribed, no change"
      else
        subscriber.update!(unsubscribed_at: Time.current, confirmation_token_digest: nil)
        Rails.logger.info "Deck news unsubscribed: subscriber #{subscriber.id}"
      end
      subscriber
    end

    # --- Helpers ------------------------------------------------------------

    def self.digest(raw)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "mailing_list:#{raw}")
    end

    # A confirmed row keeps its digest, so opening the link a second time says
    # "you are on the list" instead of "invalid"; that changes nothing. An
    # unconfirmed row's link dies at EXPIRY, and unsubscribing clears it.
    def self.find_for_confirmation(raw_token)
      return nil if raw_token.blank?

      subscriber = MailingListSubscriber.find_by(confirmation_token_digest: digest(raw_token))
      return nil unless subscriber && subscriber.unsubscribed_at.nil?
      return subscriber if subscriber.confirmed_at
      return nil unless subscriber.confirmation_sent_at && subscriber.confirmation_sent_at > EXPIRY.ago

      subscriber
    end
    private_class_method :find_for_confirmation
  end
end
