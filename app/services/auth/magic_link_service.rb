module Auth
  # Handles passwordless "magic link" sign-in for both existing users and brand-new
  # registrations. Tokens are single-use and expire after EXPIRY.
  #
  # Security notes:
  # - We store only a SHA-256/HMAC digest of the token, never the raw token.
  # - Existing users use dedicated columns (magic_link_token / magic_link_sent_at) so
  #   we never collide with Devise's password-reset token.
  # - New-user tokens live in Rails.cache (hashed token as the key, 15 minutes,
  #   single use) as a pending sign-up carrying the email and return path. No
  #   users row exists until a person confirms the sign-up: opening the link
  #   (GET) only shows a confirmation page, and the account is created by the
  #   POST from it (complete_sign_up). Corporate mail scanners follow every link
  #   in a message; when opening the link created the account, they made one for
  #   every address a script typed into /auth (August-October 2026).
  class MagicLinkService
    EXPIRY = 15.minutes

    Result = Struct.new(:success, :message, keyword_init: true) do
      def success?
        success
      end
    end

    # A consumed link: the user to sign in and the same-site path the link was
    # requested from (nil when there was none). Magic links are often opened
    # later, in another browser, so the path travels with the token on the
    # server (users.magic_link_return_to, or the new-user cache entry), never
    # in the link itself.
    Redemption = Struct.new(:user, :return_to, keyword_init: true)

    # --- Delivery -----------------------------------------------------------

    def self.deliver(email, return_to: nil)
      new(email, return_to: return_to).deliver
    end

    def initialize(email, return_to: nil)
      @email = email.to_s.strip.downcase
      @return_to = ReturnPath.sanitize(return_to)
    end

    def deliver
      unless @email.match?(URI::MailTo::EMAIL_REGEXP)
        return Result.new(success: false, message: "Please enter a valid email address.")
      end

      raw = SecureRandom.urlsafe_base64(32)
      user = User.find_by(email: @email)

      if user
        user.update!(magic_link_token: self.class.digest(raw), magic_link_sent_at: Time.current,
                     magic_link_return_to: @return_to)
        UserMailer.magic_link_email(user, raw).deliver_later
        Rails.logger.info "Magic link sent to user #{user.id}#{' with a return path' if @return_to}"
      else
        Rails.cache.write(self.class.cache_key(self.class.digest(raw)), { email: @email, return_to: @return_to }, expires_in: EXPIRY)
        UserMailer.magic_link_registration_email(@email, raw).deliver_later
        Rails.logger.info "Magic link sent for a new sign-up; no account is created until the link is confirmed"
      end

      Result.new(success: true, message: "Check your email for a magic link to sign in.")
    end

    # --- Consumption --------------------------------------------------------

    # Returns the existing User to sign in, or nil. Never creates an account.
    def self.consume(raw_token)
      redeem(raw_token)&.user
    end

    # Existing accounts only: returns a Redemption (user + return path), or nil
    # if the token is invalid/expired. Opening the link signs in straight away,
    # as it always has. A pending sign-up is NOT redeemed here (see
    # pending_sign_up? and complete_sign_up). The return path is re-checked on
    # the way out.
    def self.redeem(raw_token)
      return nil if raw_token.blank?

      user = User.find_by(magic_link_token: digest(raw_token))
      return nil unless user&.magic_link_sent_at && user.magic_link_sent_at > EXPIRY.ago

      return_to = user.magic_link_return_to
      user.update!(magic_link_token: nil, magic_link_sent_at: nil, magic_link_return_to: nil)
      Redemption.new(user: user, return_to: ReturnPath.sanitize(return_to))
    end

    # True while a new-account link is unused and unexpired. Reads only.
    def self.pending_sign_up?(raw_token)
      return false if raw_token.blank?

      Rails.cache.read(cache_key(digest(raw_token))).try(:[], :email).present?
    end

    # Confirms a pending sign-up: claims it (single use), creates the account
    # and returns a Redemption, or nil if the link is unknown, expired or
    # already used. The claim is the cache delete: only the request whose
    # delete removed the entry goes on (Solid Cache deletes by row, so two
    # simultaneous confirmations cannot both create and sign in).
    def self.complete_sign_up(raw_token)
      return nil if raw_token.blank?

      key = cache_key(digest(raw_token))
      data = Rails.cache.read(key)
      return nil unless data.try(:[], :email).present?
      return nil unless Rails.cache.delete(key)

      created = false
      user = User.find_or_create_by!(email: data[:email]) do |u|
        u.password = SecureRandom.alphanumeric(24)
        u.password_set_manually = false
        created = true
      end
      Rails.logger.info "Magic-link sign-up confirmed: #{created ? 'created' : 'found existing'} user #{user.id}"
      Redemption.new(user: user, return_to: ReturnPath.sanitize(data[:return_to]))
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
