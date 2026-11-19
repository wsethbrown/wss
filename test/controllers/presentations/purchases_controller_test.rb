require "test_helper"

# B7 / M2, M13: ownership is checked inside the lock, and a lapsed credit-owner
# may buy the deck outright.
class Presentations::PurchasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Purchase Deck", content: "Story.", price: 15)
    @deck.update_column(:published, true)
    sign_in @user
  end

  def own(type)
    UserPresentation.create!(user: @user, presentation: @deck, purchase_type: type, purchased_at: Time.current)
  end

  test "double-submitting the credit unlock spends one credit" do
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    CreditTransaction.record!(user: @user, amount: 2, transaction_type: "granted")

    post presentation_purchases_path(@deck), params: { purchase_method: "credit" }
    post presentation_purchases_path(@deck), params: { purchase_method: "credit" }

    assert_equal 1, UserPresentation.where(user: @user, presentation: @deck).count
    assert_equal 1, @user.reload.credits
    assert_equal CreditTransaction.balance_for(@user), @user.credits
  end

  test "a direct owner is sent back to the deck" do
    own("direct")
    get new_presentation_purchase_path(@deck)
    assert_redirected_to presentation_path(@deck)
  end

  test "an active credit owner is sent back to the deck" do
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    own("credit")
    get new_presentation_purchase_path(@deck)
    assert_redirected_to presentation_path(@deck)
  end

  test "a lapsed credit owner can reach checkout and start a direct purchase" do
    @user.update!(subscription_status: "canceled", subscription_ends_at: 1.day.ago)
    own("credit")

    get new_presentation_purchase_path(@deck)
    assert_response :success

    session = Struct.new(:url).new("https://checkout.stripe.test/c/pay")
    Stripe::Checkout::Session.stubs(:create).returns(session)
    @user.update_column(:stripe_customer_id, "cus_test_b7")
    post presentation_purchases_path(@deck), params: { purchase_method: "direct" }
    assert_redirected_to "https://checkout.stripe.test/c/pay"
  end

  test "a lapsed credit owner still cannot spend a credit" do
    @user.update!(subscription_status: "canceled", subscription_ends_at: 1.day.ago)
    own("credit")
    assert_no_difference -> { CreditTransaction.count } do
      post presentation_purchases_path(@deck), params: { purchase_method: "credit" }
    end
  end

  test "claiming a free deck twice leaves one row" do
    free = Presentation.create!(author: users(:admin), title: "Free Deck", content: "Story.", price: 0)
    free.update_column(:published, true)
    post presentation_purchases_path(free), params: { purchase_method: "direct" }
    post presentation_purchases_path(free), params: { purchase_method: "direct" }
    assert_equal 1, UserPresentation.where(user: @user, presentation: free).count
  end

  test "the library checks ownership with one query, not one per card" do
    5.times { |i| Presentation.create!(author: users(:admin), title: "Lib #{i}", content: "Story.", price: 5).update_column(:published, true) }
    queries = []
    sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload[:sql] if payload[:sql] =~ /FROM "user_presentations"/
    end
    get presentations_path
    assert_response :success
    assert_operator queries.size, :<=, 1, queries.join("\n")
  ensure
    ActiveSupport::Notifications.unsubscribe(sub)
  end
end
