class UserMailer < ApplicationMailer
  default from: 'Whiskey Share Society <noreply@send.whiskeysharesociety.com>'

  def magic_link_email(user, token)
    @user = user
    @token = token
    @magic_link_url = magic_link_url(token: @token)
    
    mail(
      to: @user.email,
      subject: 'Your Magic Link for Whiskey Share Society'
    )
  end

  def magic_link_registration_email(email, token)
    @email = email
    @token = token
    @magic_link_url = magic_link_url(token: @token)
    
    mail(
      to: @email,
      subject: 'Welcome to Whiskey Share Society - Complete Your Registration'
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

  def email_change_verification(user, new_email, token)
    @user = user
    @new_email = new_email
    @token = token
    @verification_url = verify_email_change_url(token: @token)
    
    mail(
      to: @user.email,  # Send to current email for verification
      subject: 'Verify Your Email Change Request'
    )
  end

  def email_change_confirmation(user, new_email, token)
    @user = user
    @new_email = new_email
    @token = token
    @verification_url = verify_email_change_url(token: @token)
    
    mail(
      to: @new_email,
      subject: 'Confirm Your New Email Address'
    )
  end
end