module Auth
  # A signed-in user's change of email address (B8, S6).
  #
  # The address is the account credential (magic links sign in whoever holds
  # the mailbox), so the change completes only from the NEW mailbox: the
  # confirm link goes there, and the current address gets a notice with no
  # link. Like MagicLinkService, only an HMAC digest of the token is stored
  # (in users.email_change_token); the raw token exists only in the email.
  class EmailChangeService
    EXPIRY = 1.hour

    Result = Struct.new(:success, :message, :user, keyword_init: true) do
      def success?
        success
      end
    end

    def self.normalize(email)
      email.to_s.strip.downcase
    end

    def self.digest(raw)
      MagicLinkService.digest(raw)
    end

    # --- Request (signed in) -------------------------------------------------

    def self.request(user, new_email)
      email = normalize(new_email)

      refusal =
        if email.blank?
          "Please enter a new email address."
        elsif !email.match?(URI::MailTo::EMAIL_REGEXP)
          "Please enter a valid email address."
        elsif email == normalize(user.email)
          "The new email address must be different from your current email."
        elsif taken?(email, user)
          "This email address is already in use."
        end

      if refusal
        Rails.logger.info "Email change request by user #{user.id} refused: #{refusal}"
        return Result.new(success: false, message: refusal, user: user)
      end

      raw = SecureRandom.urlsafe_base64(32)
      user.update!(
        unconfirmed_email: email,
        email_change_token: digest(raw),
        email_change_token_expires_at: EXPIRY.from_now
      )

      UserMailer.email_change_confirmation(user, email, raw).deliver_later
      UserMailer.email_change_notice(user, email).deliver_later
      Rails.logger.info "Email change requested by user #{user.id}: confirmation enqueued to the new address, notice to the current one"

      Result.new(
        success: true,
        user: user,
        message: "A verification link has been sent to #{email}. Please check that inbox and click the link to confirm the email change."
      )
    end

    # --- Confirm (from the new mailbox) --------------------------------------

    def self.confirm(raw_token)
      user = raw_token.present? ? User.find_by(email_change_token: digest(raw_token)) : nil

      unless user && user.unconfirmed_email.present?
        Rails.logger.warn "Email change confirmation rejected: no pending change matches the presented token"
        return Result.new(success: false, message: "Invalid verification link.")
      end

      if user.email_change_token_expires_at.nil? || user.email_change_token_expires_at < Time.current
        clear_pending(user)
        Rails.logger.warn "Email change confirmation rejected for user #{user.id}: link expired"
        return Result.new(success: false, user: user,
                          message: "Verification link has expired. Please request a new email change.")
      end

      if taken?(user.unconfirmed_email, user)
        clear_pending(user)
        Rails.logger.warn "Email change confirmation rejected for user #{user.id}: address taken since the request"
        return Result.new(success: false, user: user, message: "This email address is already in use.")
      end

      old_email = user.email
      # Revoke every sign-in path still tied to the old mailbox (same set the
      # admin email change clears): magic link, invitation, password reset and
      # remembered sessions.
      user.update!(
        email: user.unconfirmed_email,
        unconfirmed_email: nil,
        email_change_token: nil,
        email_change_token_expires_at: nil,
        magic_link_token: nil, magic_link_sent_at: nil,
        invitation_token_digest: nil,
        reset_password_token: nil, reset_password_sent_at: nil,
        remember_created_at: nil
      )
      Rails.logger.info "Email change confirmed for user #{user.id} (sign-in tokens and remembered sessions revoked)"

      Result.new(
        success: true,
        user: user,
        message: "Your email has been successfully changed from #{old_email} to #{user.email}. Please sign in again with your new email address."
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Rails.logger.error "Email change confirmation failed for user #{user&.id.inspect}: #{e.class}: #{e.message}"
      clear_pending(user) if user
      Result.new(success: false, user: user, message: "This email address is already in use.")
    end

    def self.taken?(email, user)
      User.where("LOWER(email) = ?", normalize(email)).where.not(id: user.id).exists?
    end

    def self.clear_pending(user)
      user.reload.update!(unconfirmed_email: nil, email_change_token: nil, email_change_token_expires_at: nil)
    end
    private_class_method :taken?, :clear_pending
  end
end
