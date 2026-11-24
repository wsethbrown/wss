require "test_helper"

# Turnstile is off unless both keys are set. When on, a token is checked with
# Cloudflare's siteverify endpoint; anything other than a clear "success"
# refuses, and an endpoint that errors, times out or answers nonsense refuses
# too (fail closed). The HTTP call is stubbed: no test reaches Cloudflare.
class TurnstileTest < ActiveSupport::TestCase
  setup do
    @saved = ENV.to_h.slice("TURNSTILE_SITE_KEY", "TURNSTILE_SECRET_KEY")
    ENV["TURNSTILE_SITE_KEY"] = "site-key-test"
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key-test"
  end

  teardown do
    %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY].each { |k| @saved.key?(k) ? ENV[k] = @saved[k] : ENV.delete(k) }
  end

  def http_response(klass, body)
    klass.new("1.1", klass == Net::HTTPOK ? "200" : "500", "").tap do |r|
      r.instance_variable_set(:@read, true)
      r.instance_variable_set(:@body, body)
    end
  end

  test "disabled unless both keys are set" do
    assert Turnstile.enabled?
    ENV.delete("TURNSTILE_SECRET_KEY")
    assert_not Turnstile.enabled?
    ENV["TURNSTILE_SECRET_KEY"] = "secret-key-test"
    ENV["TURNSTILE_SITE_KEY"] = ""
    assert_not Turnstile.enabled?
  end

  test "when disabled, verification passes without any HTTP call" do
    ENV.delete("TURNSTILE_SITE_KEY")
    Turnstile.expects(:post_siteverify).never
    result = Turnstile.verify(nil, remote_ip: "203.0.113.9")
    assert result.passed?
    assert_equal :disabled, result.status
  end

  test "a missing token is refused without an HTTP call" do
    Turnstile.expects(:post_siteverify).never
    result = Turnstile.verify("", remote_ip: "203.0.113.9")
    assert_not result.passed?
    assert_equal :missing, result.status
  end

  test "success: sends the secret, token and visitor IP, and passes" do
    Turnstile.expects(:post_siteverify)
             .with({ "secret" => "secret-key-test", "response" => "tok", "remoteip" => "203.0.113.9" })
             .returns(http_response(Net::HTTPOK, { success: true, "error-codes": [] }.to_json))
    result = Turnstile.verify("tok", remote_ip: "203.0.113.9")
    assert result.passed?
    assert_equal :passed, result.status
  end

  test "failure: Cloudflare says no, so it is refused with the error codes" do
    Turnstile.stubs(:post_siteverify)
             .returns(http_response(Net::HTTPOK, { success: false, "error-codes": [ "invalid-input-response" ] }.to_json))
    result = Turnstile.verify("tok", remote_ip: "203.0.113.9")
    assert_not result.passed?
    assert_equal :rejected, result.status
    assert_equal [ "invalid-input-response" ], result.error_codes
  end

  test "timeout: fails closed and logs the exception class at error" do
    Turnstile.stubs(:post_siteverify).raises(Net::ReadTimeout)
    logged = capture_log { @result = Turnstile.verify("tok", remote_ip: "203.0.113.9") }
    assert_not @result.passed?
    assert_equal :unavailable, @result.status
    assert_match(/ERROR.*Net::ReadTimeout/, logged)
    assert_no_match(/tok\b|secret-key-test/, logged)
  end

  test "connection failure fails closed" do
    Turnstile.stubs(:post_siteverify).raises(Errno::ECONNREFUSED)
    assert_equal :unavailable, Turnstile.verify("tok").status
  end

  test "a non-2xx answer fails closed" do
    Turnstile.stubs(:post_siteverify).returns(http_response(Net::HTTPInternalServerError, "oops"))
    assert_equal :unavailable, Turnstile.verify("tok").status
  end

  test "a malformed response fails closed" do
    [ "not json", "[]", "{}", { success: "yes" }.to_json ].each do |body|
      Turnstile.stubs(:post_siteverify).returns(http_response(Net::HTTPOK, body))
      result = Turnstile.verify("tok")
      assert_not result.passed?, "#{body.inspect} must not pass"
      assert_equal :unavailable, result.status, body
    end
  end

  test "the HTTP call uses short timeouts" do
    assert_operator Turnstile::OPEN_TIMEOUT, :<=, 5
    assert_operator Turnstile::READ_TIMEOUT, :<=, 10
  end

  private

  def capture_log
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)
    logger.formatter = ->(severity, _t, _p, msg) { "#{severity} #{msg}\n" }
    original = Rails.logger
    Rails.logger = logger
    yield
    io.string
  ensure
    Rails.logger = original
  end
end
