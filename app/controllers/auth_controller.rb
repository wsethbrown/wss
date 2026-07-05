class AuthController < ApplicationController
  include ActivityLogger

  def unified
    redirect_to root_path if user_signed_in?
  end

  def sign_in
    user = User.find_by(email: params[:user][:email])
    
    if user && user.valid_password?(params[:user][:password])
      if user.otp_required_for_login?
        # Store user_id in session for 2FA verification
        session[:user_id_for_2fa] = user.id
        redirect_to auth_path, alert: '2FA verification required'
      else
        warden.set_user(user, scope: :user)
        user.remember_me! if params[:user][:remember_me] == '1'
        log_activity(:login, nil, { method: 'password' })
        redirect_to dashboard_path, notice: 'Signed in successfully'
      end
    else
      # Re-render the auth page with a 422 so Turbo swaps in the error state
      # instead of following a redirect (which loses the entered email).
      flash.now[:alert] = 'Invalid Email or password'
      render :unified, status: :unprocessable_entity
    end
  end

  def logout
    log_activity(:logout) if current_user
    sign_out(current_user) if user_signed_in?
    redirect_to root_path
  end
end
