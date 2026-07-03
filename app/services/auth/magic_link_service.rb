module Auth
  # Handles passwordless "magic link" sign-in for both existing users and brand-new
  # registrations. Tokens are single-use and expire after EXPIRY.
  #
  # Security notes:
  # - We store only a SHA-256/HMAC digest of the token, never the raw token.
  # - Existing users use dedicated columns (magic_link_token / magic_link_sent_at) so
  #   we never collide with Devise's password-reset token.
  # - New-user tokens live in Rails.cache until consumed, so no half-built User rows.
  class MagicLinkService
    EXPIRY = 15.minutes

    Result = Struct.new(:success, :message, keyword_init: true) do
      def success?
        success
      end
    end

    # --- Delivery -----------------------------------------------------------

    def self.deliver(email)
      new(email).deliver
    end

    def initialize(email)
      @email = email.to_s.strip.downcase
    end

    def deliver
      unless @email.match?(URI::MailTo::EMAIL_REGEXP)
        return Result.new(success: false, message: "Please enter a valid email address.")
      end

      raw = SecureRandom.urlsafe_base64(32)
      user = User.find_by(email: @email)

      if user
        user.update!(magic_link_token: self.class.digest(raw), magic_link_sent_at: Time.current)
        UserMailer.magic_link_email(user, raw).deliver_later
      else
        Rails.cache.write(self.class.cache_key(self.class.digest(raw)), { email: @email }, expires_in: EXPIRY)
        UserMailer.magic_link_registration_email(@email, raw).deliver_later
      end

      Result.new(success: true, message: "Check your email for a magic link to sign in.")
    end

    # --- Consumption --------------------------------------------------------

    # Returns a persisted User to sign in, or nil if the token is invalid/expired.
    def self.consume(raw_token)
      return nil if raw_token.blank?

      token_digest = digest(raw_token)

      # Existing-user path.
      user = User.find_by(magic_link_token: token_digest)
      if user&.magic_link_sent_at && user.magic_link_sent_at > EXPIRY.ago
        user.update!(magic_link_token: nil, magic_link_sent_at: nil)
        return user
      end

      # New-user registration path (token held in cache).
      data = Rails.cache.read(cache_key(token_digest))
      if data && data[:email].present?
        Rails.cache.delete(cache_key(token_digest))
        return User.find_or_create_by!(email: data[:email]) do |u|
          u.password = SecureRandom.alphanumeric(24)
          u.password_set_manually = false
        end
      end

      nil
    end

    # --- Helpers ------------------------------------------------------------

    def self.digest(raw)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, raw.to_s)
    end

    def self.cache_key(token_digest)
      "magic_link:#{token_digest}"
    end
  end
end
