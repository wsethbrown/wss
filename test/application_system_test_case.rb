require "test_helper"
require_relative "support/system_test_timeline"
require_relative "support/stale_node_retry"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # On failure, prints the browser-side timeline (loads, paints, Turbo, clicks)
  # and saves it beside the failure screenshot. See the module for details.
  include SystemTestTimeline

  # A test must not end while its page still has a request in flight.
  #
  # After each test Capybara navigates to about:blank and clears the cookies.
  # A response that arrives after that still sets its cookies, because the
  # server already sent them: a Save still in flight when a test ended put
  # the admin's session cookie back, so the NEXT test started signed in and
  # /auth redirected away from the sign-in form (CI run 45069677419;
  # reproduced with --seed 7423 and 1090). Turbo marks a form submission and
  # a page visit with aria-busy="true", and the deck page's customer preview
  # marks its own requests the same way, so waiting for no aria-busy here lets
  # every such response land before the reset. It fails the test, naming the
  # cause, if the page is still busy after Capybara's wait.
  #
  # before_teardown, not a teardown block: Rails resets the Capybara session
  # in after_teardown before teardown blocks run, which would be too late.
  def before_teardown
    if page.driver.is_a?(Capybara::Selenium::Driver) && page.current_url.to_s.start_with?("http")
      assert_no_selector "[aria-busy='true']", visible: :all, wait: Capybara.default_max_wait_time
    end
  ensure
    super
  end

  # Every sign-in helper starts here: the sign-in page, signed out. If the
  # browser is still signed in from an earlier test, /auth redirects away and
  # this says so instead of failing later on a missing field.
  def visit_sign_in_page
    visit auth_path
    assert_current_path auth_path, ignore_query: true
  end
end
