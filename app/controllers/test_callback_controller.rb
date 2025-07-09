class TestCallbackController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def callback
    Rails.logger.info "=== TEST CALLBACK RECEIVED ==="
    Rails.logger.info "Method: #{request.method}"
    Rails.logger.info "Path: #{request.path}"
    Rails.logger.info "Params: #{params.inspect}"
    Rails.logger.info "Headers: #{request.headers.to_h.select { |k,v| k.start_with?('HTTP_') }}"
    Rails.logger.info "Body: #{request.body.read}"
    request.body.rewind
    
    # Try to handle as Apple callback
    if params[:code] || params[:id_token]
      # Sign in the user
      user = User.find_or_create_by(email: 'wsethbrown@gmail.com') do |u|
        u.first_name = 'Seth'
        u.last_name = 'Brown'
        u.password = SecureRandom.hex(16)
        u.provider = 'apple'
        u.uid = SecureRandom.hex(8)
      end
      
      sign_in(user)
      redirect_to account_path, notice: "Successfully signed in with Apple!"
    else
      render plain: "Callback received. Check logs for details.", status: :ok
    end
  end
end