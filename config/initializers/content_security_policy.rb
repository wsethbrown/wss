# Be sure to restart your server when you modify this file.

# Content Security Policy, REPORT-ONLY (B18 / S15).
#
# This policy is deliberately NOT enforced: browsers evaluate it and log what
# they would have blocked to the console, but nothing is blocked. The list of
# things that still need fixing before it can be enforced is in
# docs/redesign/CSP_REPORT_ONLY.md. Flip `content_security_policy_report_only`
# to false only after that list is empty and the ten main pages load clean.
#
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    # Google Fonts: stylesheet from fonts.googleapis.com, files from fonts.gstatic.com.
    policy.font_src    :self, :https, :data
    # Uploads are served from our storage host (R2 in production), so https is allowed.
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.base_uri    :self
    policy.form_action :self, :https
    policy.frame_ancestors :self
    # The Maps script is injected at runtime by location_autocomplete_controller.js.
    policy.script_src  :self, "https://maps.googleapis.com"
    policy.style_src   :self, :https
    policy.connect_src :self, "https://maps.googleapis.com"
  end

  # A fresh random nonce per request (not the session id: it is unpredictable
  # and does not depend on a session existing). Rails adds it to the importmap
  # tags and to any tag that asks for it (`nonce: true`).
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = true
end
