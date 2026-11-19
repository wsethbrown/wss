class UserMailer < ApplicationMailer
  default from: "Whiskey Share Society <noreply@send.whiskeysharesociety.com>"

  def magic_link_email(user, token)
    @user = user
    @token = token
    @magic_link_url = magic_link_url(token: @token)

    mail(
      to: @user.email,
      subject: "Your Magic Link for Whiskey Share Society"
    )
  end

  def magic_link_registration_email(email, token)
    @email = email
    @token = token
    @magic_link_url = magic_link_url(token: @token)

    mail(
      to: @email,
      subject: "Welcome to Whiskey Share Society - Complete Your Registration"
    )
  end

  def invitation_email(user, token)
    @user = user
    @inviter = user.invited_by
    @invitation_url = invitation_url(token: token)

    mail(
      to: @user.email,
      subject: "You're invited to Whiskey Share Society"
    )
  end

  # The current address hears that a change was asked for, with no link: the
  # change can only be completed from the new mailbox (B8, S6).
  def email_change_notice(user, new_email)
    @user = user
    @new_email = new_email

    mail(
      to: @user.email,
      subject: "Your email address is being changed"
    )
  end

  # The confirm link goes ONLY to the new address (B8, S6).
  def email_change_confirmation(user, new_email, token)
    @user = user
    @new_email = new_email
    @verification_url = verify_email_change_url(token: token)

    mail(
      to: @new_email,
      subject: "Confirm Your New Email Address"
    )
  end
end
