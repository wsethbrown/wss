require "test_helper"

# B7 / M12: a deck anyone owns, or that appears in the credit ledger, is never
# deleted; deleting it would remove buyers' lifetime access or fail on a FK.
class Admin::PresentationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Doomed Deck", content: "Story.", price: 10)
    @buyer = users(:john)
    sign_in users(:admin)
  end

  test "an owned deck is refused, with its ownership rows intact" do
    UserPresentation.create!(user: @buyer, presentation: @deck, purchase_type: "direct", purchased_at: Time.current)
    assert_no_difference [ "Presentation.count", "UserPresentation.count" ] do
      delete admin_presentation_path(@deck)
    end
    assert_redirected_to admin_presentations_path
    assert_match(/unpublish/i, flash[:alert])
  end

  test "a deck in the credit ledger is refused" do
    @buyer.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    CreditTransaction.record!(user: @buyer, amount: 1, transaction_type: "granted")
    CreditTransaction.use_credit(@buyer, @deck)
    @buyer.user_presentations.destroy_all # ownership gone, ledger row remains
    assert_no_difference [ "Presentation.count", "CreditTransaction.count" ] do
      delete admin_presentation_path(@deck)
    end
    assert_match(/unpublish/i, flash[:alert])
  end

  test "an owner-less deck with a download log is refused, not a 500" do
    DownloadLog.create!(user: @buyer, presentation: @deck, file_type: "sneak_peek", downloaded_at: Time.current)
    assert_no_difference [ "Presentation.count", "DownloadLog.count" ] do
      delete admin_presentation_path(@deck)
    end
    assert_redirected_to admin_presentations_path
    assert_match(/unpublish/i, flash[:alert])
  end

  test "an unowned deck is deleted" do
    assert_difference -> { Presentation.count }, -1 do
      delete admin_presentation_path(@deck)
    end
    assert_redirected_to admin_presentations_path
  end

  test "a limited admin cannot delete at all" do
    delete destroy_user_session_path
    sign_in users(:limited_admin)
    assert_no_difference -> { Presentation.count } do
      delete admin_presentation_path(@deck)
    end
  end
end
