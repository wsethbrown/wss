require "test_helper"

class MagicLinkWebFormTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(
      email: 'wsethbrown@gmail.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Seth',
      last_name: 'Brown'
    )
    
    # Clear any existing emails
    mail_dir = Rails.root.join('tmp/mail')
    Dir.glob("#{mail_dir}/*").each { |file| File.delete(file) } if Dir.exist?(mail_dir)
  end

  def teardown
    # Clean up emails after test
    mail_dir = Rails.root.join('tmp/mail')
    Dir.glob("#{mail_dir}/*").each { |file| File.delete(file) } if Dir.exist?(mail_dir)
  end

  test "auth page loads correctly and shows magic link option" do
    get auth_path
    
    assert_response :success
    assert_select 'button', text: /Sign in with magic link/
    assert_select '#magic-link-form', count: 1
  end

  test "magic link form submission works exactly like web browser" do
    # First visit the auth page (like a real user)
    get auth_path
    assert_response :success
    
    # Check initial email count
    initial_count = Dir.glob(Rails.root.join('tmp/mail/*')).count
    
    # Submit the magic link form with the exact same parameters a browser would send
    post magic_links_path, params: {
      email: @user.email,
      authenticity_token: authenticity_token_from_form
    }, headers: {
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Content-Type' => 'application/x-www-form-urlencoded'
    }
    
    # Debug output
    puts "📊 Response status: #{response.status}"
    puts "📊 Response location: #{response.location}"
    puts "📊 Flash messages: #{flash.to_h}"
    
    # Check if redirect happened
    assert_redirected_to auth_path
    
    # Follow the redirect to check flash messages
    follow_redirect!
    assert_response :success
    
    # Check if email was generated
    final_count = Dir.glob(Rails.root.join('tmp/mail/*')).count
    puts "📊 Email count: #{initial_count} → #{final_count}"
    
    assert_equal initial_count + 1, final_count, "Email should have been generated"
    
    # Verify flash message appeared
    assert_match(/magic link/, flash[:notice])
  end

  test "magic link form submission without CSRF token" do
    get auth_path
    
    # Submit without authenticity token (might be the issue)
    post magic_links_path, params: { email: @user.email }
    
    puts "📊 Response without CSRF: #{response.status}"
    
    # Rails should either accept it or return error
    assert_response :redirect
  end

  private

  def authenticity_token_from_form
    # Extract CSRF token from the auth page
    get auth_path
    css = Nokogiri::HTML(response.body)
    csrf_token = css.at('meta[name="csrf-token"]')&.[]('content')
    csrf_token || 'test-token'
  end
end