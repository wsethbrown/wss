require "test_helper"

# B3b: production is Client -> Cloudflare -> kamal-proxy -> app. Cloudflare's
# edge addresses must be trusted proxies so request.remote_ip is the visitor,
# not the edge (otherwise everyone behind one edge shares a rate-limit bucket).
# Only addresses actually inside Cloudflare's ranges may be skipped over: a
# header from anywhere else must not be able to choose the client IP.
class TrustedProxiesTest < ActiveSupport::TestCase
  DOCKER_HOP = "172.18.0.2"            # kamal-proxy, private: trusted by Rails' defaults
  CF_EDGE_V4 = "172.70.42.17"          # inside 172.64.0.0/13
  CF_EDGE_V6 = "2a06:98c0:3600::103"   # inside 2a06:98c0::/29
  CLIENT = "203.0.113.7"

  # Runs the real RemoteIp middleware with the app's own configuration.
  def remote_ip_for(remote_addr:, forwarded_for:)
    config = Rails.application.config.action_dispatch
    echo = ->(env) { [ 200, {}, [ ActionDispatch::Request.new(env).remote_ip ] ] }
    middleware = ActionDispatch::RemoteIp.new(echo, config.ip_spoofing_check, config.trusted_proxies)
    env = Rack::MockRequest.env_for("/", "REMOTE_ADDR" => remote_addr, "HTTP_X_FORWARDED_FOR" => forwarded_for)
    middleware.call(env).last.first
  end

  test "the app's middleware stack is built with the Cloudflare list" do
    proxies = Rails.application.config.action_dispatch.trusted_proxies
    assert proxies.any? { |range| range === IPAddr.new(CF_EDGE_V4) }
    assert proxies.any? { |range| range === IPAddr.new(CF_EDGE_V6) }
    # Rails' defaults (loopback and private ranges) are still trusted.
    assert proxies.any? { |range| range === IPAddr.new(DOCKER_HOP) }
  end

  test "a Cloudflare IPv4 edge as last hop yields the visitor's address" do
    assert_equal CLIENT, remote_ip_for(remote_addr: DOCKER_HOP, forwarded_for: "#{CLIENT}, #{CF_EDGE_V4}")
  end

  test "a Cloudflare IPv6 edge as last hop yields the visitor's address" do
    assert_equal CLIENT, remote_ip_for(remote_addr: DOCKER_HOP, forwarded_for: "#{CLIENT}, #{CF_EDGE_V6}")
  end

  test "a value the visitor put in front of Cloudflare's entry is ignored" do
    assert_equal CLIENT,
                 remote_ip_for(remote_addr: DOCKER_HOP, forwarded_for: "198.51.100.99, #{CLIENT}, #{CF_EDGE_V4}")
  end

  test "a non-Cloudflare public last hop cannot choose the client address" do
    attacker = "192.0.2.50"
    assert_equal attacker, remote_ip_for(remote_addr: DOCKER_HOP, forwarded_for: "#{CLIENT}, #{attacker}")
  end

  test "bypassing Cloudflare with a forged Cloudflare hop still yields the real sender" do
    # Direct to the origin: kamal-proxy appends the attacker's own address last.
    attacker = "192.0.2.50"
    assert_equal attacker,
                 remote_ip_for(remote_addr: DOCKER_HOP, forwarded_for: "#{CLIENT}, #{CF_EDGE_V4}, #{attacker}")
  end
end

# End to end through the real stack: two visitors behind the same Cloudflare
# edge get separate per-IP rate-limit buckets.
class TrustedProxiesRateLimitTest < ActionDispatch::IntegrationTest
  setup { RateLimitStore.enable_for_test! }
  teardown { RateLimitStore.disable_for_test! }

  def email_check_from(client)
    post "/auth/email_check", params: { email: "a@example.com" }, as: :json,
                              headers: { "REMOTE_ADDR" => "172.18.0.2",
                                         "HTTP_X_FORWARDED_FOR" => "#{client}, 172.70.42.17" }
  end

  test "visitors behind one Cloudflare edge do not share a per-IP bucket" do
    AuthController::EMAIL_CHECK_LIMIT.times { email_check_from("203.0.113.7") }
    email_check_from("203.0.113.7")
    assert_response :too_many_requests

    email_check_from("203.0.113.8")
    assert_response :success
  end
end
