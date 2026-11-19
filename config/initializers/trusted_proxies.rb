# Production traffic is Client -> Cloudflare -> kamal-proxy -> app. Rails trusts
# only loopback and private ranges by default, so without this every request's
# remote_ip would be a Cloudflare edge address and all visitors behind one edge
# would share a per-IP rate-limit bucket.
#
# Trusting Cloudflare's ranges lets ActionDispatch::RemoteIp skip over the edge
# hop in X-Forwarded-For and return the visitor's address. Only hops inside
# these ranges are skipped, so a forged header sent straight to the origin
# cannot choose the client IP. Do NOT read CF-Connecting-IP instead: the origin
# is publicly reachable, so that header is trivially spoofable.
#
# Source: https://www.cloudflare.com/ips-v4 and https://www.cloudflare.com/ips-v6
# Taken 2026-11-19 from the published list as known at that date; NOT fetched
# live. Verify against those URLs and refresh whenever Cloudflare changes them.
CLOUDFLARE_IP_RANGES = %w[
  173.245.48.0/20
  103.21.244.0/22
  103.22.200.0/22
  103.31.4.0/22
  141.101.64.0/18
  108.162.192.0/18
  190.93.240.0/20
  188.114.96.0/20
  197.234.240.0/22
  198.41.128.0/17
  162.158.0.0/15
  104.16.0.0/13
  104.24.0.0/14
  172.64.0.0/13
  131.0.72.0/22
  2400:cb00::/32
  2606:4700::/32
  2803:f800::/32
  2405:b500::/32
  2405:8100::/32
  2a06:98c0::/29
  2c0f:f248::/32
].map { |range| IPAddr.new(range) }.freeze

# Applies in every environment; harmless locally (no Cloudflare hop there).
Rails.application.config.action_dispatch.trusted_proxies =
  ActionDispatch::RemoteIp::TRUSTED_PROXIES + CLOUDFLARE_IP_RANGES
