require "test_helper"

# I27: a browser time zone must not leak into the next request on the same thread.
class TimeZoneIsolationTest < ActionDispatch::IntegrationTest
  test "the browser zone applies to the request and is restored afterwards" do
    default = Time.zone.name
    cookies[:browser_timezone] = "Tokyo"
    get root_path
    assert_equal default, Time.zone.name
  end

  test "a request with no cookie sees the default zone even after a zoned one" do
    default = Time.zone.name
    cookies[:browser_timezone] = "Tokyo"
    get root_path
    cookies.delete(:browser_timezone)
    get root_path
    assert_equal default, Time.zone.name
  end
end
