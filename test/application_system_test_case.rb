require "test_helper"
require_relative "support/system_test_timeline"
require_relative "support/stale_node_retry"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # On failure, prints the browser-side timeline (loads, paints, Turbo, clicks)
  # and saves it beside the failure screenshot. See the module for details.
  include SystemTestTimeline

  # Start every test signed out. Capybara clears cookies when a test ends and
  # then leaves the page, in that order; a response still in flight from the
  # finished test (a save, a live preview) can set the session cookie again in
  # between, and the next test opens /auth already signed in and is redirected.
  # Seen as "Unable to find field magic-link-email" with the browser on "/".
  # By the time the next test's setup runs the browser is on about:blank with
  # nothing in flight, so clearing here is final.
  setup do
    browser = page.driver.browser
    browser.execute_cdp("Network.clearBrowserCookies") if browser.respond_to?(:execute_cdp)
  end

  # Waits until Turbo has finished the current visit: <html aria-busy> is cleared
  # and no view transition is running. Call it before `visit` when the previous
  # step was a Turbo form submit or link, so the test does not navigate away
  # from a page that is still mid-visit.
  def wait_for_turbo_visit
    assert_no_selector "html[aria-busy='true']"
    assert_no_selector "html:active-view-transition"
  end
end
