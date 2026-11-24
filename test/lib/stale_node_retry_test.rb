require "test_helper"
require_relative "../support/stale_node_retry"

# The bridge patch turns Chrome's "node does not belong to the document"
# UnknownError into a stale-element error (which Capybara retries) and leaves
# every other error alone.
class StaleNodeRetryTest < ActiveSupport::TestCase
  class FakeBridge
    def initialize(error) = @error = error

    def run = execute(:anything)

    private

    def execute(*) = raise(@error)
  end
  FakeBridge.prepend(StaleNodeRetry)

  test "the navigation-race inspector error becomes a stale element error" do
    error = Selenium::WebDriver::Error::UnknownError.new(
      'unknown error: unhandled inspector error: {"code":-32000,"message":"Node with given id does not belong to the document"}'
    )
    assert_raises(Selenium::WebDriver::Error::StaleElementReferenceError) { FakeBridge.new(error).run }
  end

  test "other unknown errors are not touched" do
    error = Selenium::WebDriver::Error::UnknownError.new("unknown error: something else")
    raised = assert_raises(Selenium::WebDriver::Error::UnknownError) { FakeBridge.new(error).run }
    assert_not_kind_of Selenium::WebDriver::Error::StaleElementReferenceError, raised
  end

  test "the real Selenium bridge carries the patch" do
    assert_includes Selenium::WebDriver::Remote::Bridge.ancestors, StaleNodeRetry
  end
end
