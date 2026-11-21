require "test_helper"

class PresentationPriceTest < ActiveSupport::TestCase
  test "a price always shows two decimals" do
    assert_equal "$19.00", Presentation.new(price: 19).formatted_price
    assert_equal "$12.99", Presentation.new(price: BigDecimal("12.99")).formatted_price
    assert_equal "$9.50", Presentation.new(price: BigDecimal("9.5")).formatted_price
  end

  test "a zero price reads Free" do
    assert_equal "Free", Presentation.new(price: 0).formatted_price
  end
end
