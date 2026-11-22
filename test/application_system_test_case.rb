require "test_helper"
require_relative "support/system_test_timeline"
require_relative "support/stale_node_retry"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # On failure, prints the browser-side timeline (loads, paints, Turbo, clicks)
  # and saves it beside the failure screenshot. See the module for details.
  include SystemTestTimeline
end
