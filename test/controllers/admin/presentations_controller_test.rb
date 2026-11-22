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

  # Re-render slide previews: the manual recovery for a failed or missing render.
  test "re-render enqueues the render job for a deck with a file" do
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
    assert_enqueued_with(job: DeckSlideRenderJob, args: [ @deck.id ]) do
      post render_slides_admin_presentation_path(@deck)
    end
    assert_redirected_to admin_presentation_path(@deck)
    assert_match(/render queued/i, flash[:notice])
  end

  test "re-render on a deck with no file gives an alert and enqueues nothing" do
    assert_no_enqueued_jobs only: DeckSlideRenderJob do
      post render_slides_admin_presentation_path(@deck)
    end
    assert_redirected_to admin_presentation_path(@deck)
    assert_match(/no deck file/i, flash[:alert])
  end

  test "re-render for an unknown deck is a 404, not a 500" do
    post render_slides_admin_presentation_path(id: 0)
    assert_response :not_found
  end

  test "a limited admin can re-render like the neighbouring actions" do
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
    delete destroy_user_session_path
    sign_in users(:limited_admin)
    assert_enqueued_with(job: DeckSlideRenderJob, args: [ @deck.id ]) do
      post render_slides_admin_presentation_path(@deck)
    end
  end

  test "a non-admin cannot re-render" do
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
    delete destroy_user_session_path
    sign_in @buyer
    assert_no_enqueued_jobs only: DeckSlideRenderJob do
      post render_slides_admin_presentation_path(@deck)
    end
    assert_response :redirect
  end

  test "a failure enqueueing the render is reported, not a 500" do
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
    DeckSlideRenderJob.stubs(:perform_later).raises(StandardError, "queue down")
    post render_slides_admin_presentation_path(@deck)
    assert_redirected_to admin_presentation_path(@deck)
    assert_match(/could not queue/i, flash[:alert])
  end

  # Unpublishing takes a deck out of the library, not away from its owners;
  # the admin is told how many people own it before and after.
  def published_with_owners(count)
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
    @deck.slide_images.attach(io: File.open(Rails.root.join("test/fixtures/files/slides/slide-01.png"), "rb"),
                              filename: "slide-01.png", content_type: "image/png")
    @deck.update!(published: true)
    [ users(:john), users(:jane), users(:seth) ].first(count).each do |user|
      UserPresentation.create!(user: user, presentation: @deck, purchase_type: "direct", purchased_at: Time.current)
    end
  end

  test "the unpublish button states how many people own the deck" do
    published_with_owners(2)
    get admin_presentation_path(@deck)
    assert_select "form[action=?][data-turbo-confirm*='2 people own this deck']", unpublish_admin_presentation_path(@deck)
    assert_match(/2 people own this deck/, response.body)
  end

  test "unpublishing says the owners keep the deck" do
    published_with_owners(1)
    post unpublish_admin_presentation_path(@deck)
    assert_not @deck.reload.published?
    assert_match(/1 person owns this deck and keeps it/, flash[:notice])
  end
end
