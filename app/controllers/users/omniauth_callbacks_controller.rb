class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include ActivityLogger

  # Apple posts its callback as a form; skip forgery protection for that provider only.
  protect_from_forgery except: [ :apple ]

  def google_oauth2
    handle_auth("Google")
  end

  def apple
    handle_auth("Apple")
  end

  def failure
    message = case params[:message]
    when "csrf_detected" then "Security validation failed. Please try again."
    when "invalid_credentials" then "Invalid credentials. Please try again."
    else "Authentication failed. Please try again."
    end

    redirect_to auth_path, alert: message
  end

  private

  def handle_auth(provider)
    auth = request.env["omniauth.auth"]

    if auth.nil?
      redirect_to auth_path, alert: "Authentication data not received. Please try again."
      return
    end

    @user = User.from_omniauth(auth)

    if @user.persisted?
      sign_in @user, event: :authentication
      log_activity(:login, nil, { method: provider.downcase })
      redirect_to after_sign_in_path_for(@user), notice: "Successfully signed in with #{provider}!"
    else
      session["devise.oauth_data"] = auth.except(:extra)
      redirect_to auth_path, alert: @user.errors.full_messages.to_sentence.presence || "Could not sign you in."
    end
  rescue => e
    Rails.logger.error "OAuth error (#{provider}): #{e.class} - #{e.message}"
    redirect_to auth_path, alert: "Authentication error. Please try again."
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || account_path
  end
end
