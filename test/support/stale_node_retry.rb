# Chrome 157 answers a query that races a page navigation with
#   unknown error: unhandled inspector error: "Node with given id does not belong to the document"
# instead of a stale-element error. Capybara retries stale-element errors while a
# page swaps, but treats an UnknownError as fatal, so a test that asserts on text
# right after submitting a form can error out mid-navigation (seen in CI on
# MagicLinksTest, where the timeline showed /auth reloading as the assertion ran).
#
# Re-raise that one message as the stale-element error it is, so Capybara's
# normal wait-and-retry applies. Every other UnknownError is left alone.
require "selenium-webdriver"

module StaleNodeRetry
  MESSAGE = "does not belong to the document".freeze

  private

  def execute(*args, **kwargs)
    super
  rescue Selenium::WebDriver::Error::UnknownError => e
    raise unless e.message.include?(MESSAGE)

    raise Selenium::WebDriver::Error::StaleElementReferenceError, e.message
  end
end

Selenium::WebDriver::Remote::Bridge.prepend(StaleNodeRetry)
