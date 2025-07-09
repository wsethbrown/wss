require "test_helper"

class MagicLinksControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Test',
      last_name: 'User'
    )
  end

  def teardown
    # Clean up any generated emails
    mail_dir = Rails.root.join('tmp/mail')
    Dir.glob("#{mail_dir}/*").each { |file| File.delete(file) } if Dir.exist?(mail_dir)
  end

  test "should create magic link for existing user" do
    assert_difference -> { Dir.glob(Rails.root.join('tmp/mail/*')).count }, 1 do
      post magic_links_path, params: { email: @user.email }
    end
    
    assert_redirected_to auth_path
    assert_not_nil flash[:notice]
    assert_match(/magic link/, flash[:notice])
    
    # Verify user has reset token
    @user.reload
    assert_not_nil @user.reset_password_token
    assert_not_nil @user.reset_password_sent_at
  end

  test "should create magic link for new user" do
    new_email = 'newuser@example.com'
    
    assert_difference -> { Dir.glob(Rails.root.join('tmp/mail/*')).count }, 1 do
      post magic_links_path, params: { email: new_email }
    end
    
    assert_redirected_to auth_path
    assert_not_nil flash[:notice]
    assert_match(/magic link/, flash[:notice])
    
    # Verify session has magic link data (check string keys since they're stored as strings)
    assert_not_nil session[:magic_link_data]
    assert_equal new_email, session[:magic_link_data]['email']
    assert session[:magic_link_data]['is_new_user']
  end

  test "should handle magic link click for existing user" do
    token = SecureRandom.urlsafe_base64(16)
    digest = Devise.token_generator.digest(User, :reset_password_token, token)
    @user.update!(
      reset_password_token: digest,
      reset_password_sent_at: Time.current
    )
    
    get magic_link_path(token: token)
    
    assert_redirected_to account_path
    assert_not_nil flash[:notice]
    assert user_signed_in?
  end

  private

  def user_signed_in?
    !session[:user_id].nil? || controller.user_signed_in?
  end
end