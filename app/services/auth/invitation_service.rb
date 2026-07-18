module Auth
  # Admin-created accounts (owner-requested, July 2026). An admin sets up a
  # User for someone and emails them a claim link; accepting the link signs
  # them in once, after which they authenticate like everyone else (magic
  # link to the same address, or Google). Same token discipline as
  # MagicLinkService: only an HMAC digest is stored, single-use, expiring —
  # but on dedicated invitation columns and with a two-week window, since
  # invitees aren't waiting at their inbox the way magic-link users are.
  class InvitationService
    EXPIRY = 14.days

    Result = Struct.new(:success, :message, :user, :raw_token, keyword_init: true) do
      def success?
        success
      end
    end

    def self.invite!(email:, first_name:, last_name:, invited_by:)
      normalized = email.to_s.strip.downcase
      unless normalized.match?(URI::MailTo::EMAIL_REGEXP)
        return Result.new(success: false, message: "Please enter a valid email address.")
      end
      if User.exists?(email: normalized)
        return Result.new(success: false, message: "#{normalized} already has an account.")
      end

      raw = SecureRandom.urlsafe_base64(32)
      user = User.create!(
        email: normalized,
        first_name: first_name.to_s.strip,
        last_name: last_name.to_s.strip,
        password: SecureRandom.alphanumeric(24),
        password_set_manually: false,
        invited_by: invited_by,
        invitation_token_digest: MagicLinkService.digest(raw),
        invitation_sent_at: Time.current
      )
      UserMailer.invitation_email(user, raw).deliver_later
      Result.new(success: true, message: "Invitation sent to #{normalized}.", user: user, raw_token: raw)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, message: e.record.errors.full_messages.to_sentence)
    end

    # A fresh link for a pending invitee; accepted accounts are done inviting.
    def self.resend!(user)
      if user.invitation_accepted_at.present?
        return Result.new(success: false, message: "#{user.email} has already accepted their invitation.")
      end

      raw = SecureRandom.urlsafe_base64(32)
      user.update!(invitation_token_digest: MagicLinkService.digest(raw), invitation_sent_at: Time.current)
      UserMailer.invitation_email(user, raw).deliver_later
      Result.new(success: true, message: "Invitation re-sent to #{user.email}.", user: user, raw_token: raw)
    end

    # Returns the invitee to sign in, or nil for invalid/expired/used tokens.
    def self.consume(raw_token)
      return nil if raw_token.blank?

      user = User.find_by(invitation_token_digest: MagicLinkService.digest(raw_token))
      return nil unless user&.invitation_sent_at && user.invitation_sent_at > EXPIRY.ago

      user.update!(invitation_token_digest: nil, invitation_accepted_at: Time.current)
      user
    end
  end
end
