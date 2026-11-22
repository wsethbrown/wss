require "test_helper"

# Unpublishing hides a deck from the library, search, featured lists and new
# purchases. It does not take the deck away from people who own it: anyone
# with working access (a direct owner, or a credit owner with an active
# membership, per User#can_access_presentation?) still opens its page,
# presents it and downloads its files. Everyone else gets the 404 a draft gives.
class Presentations::UnpublishedAccessTest < ActionDispatch::IntegrationTest
  setup do
    @owner = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Pulled Deck", content: "## One\n\nThe whole story.",
                                 description: "A pulled deck.", price: 15)
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 deck"), filename: "deck.pdf", content_type: "application/pdf")
    @deck.slide_images.attach(io: File.open(Rails.root.join("test/fixtures/files/slides/slide-01.png"), "rb"),
                              filename: "slide-01.png", content_type: "image/png")
    @deck.update_column(:published, false)
  end

  def own(user, type)
    UserPresentation.create!(user: user, presentation: @deck, purchase_type: type, purchased_at: Time.current)
  end

  def assert_opens_everything
    get presentation_path(@deck)
    assert_response :success
    assert_match "The whole story.", response.body
    get present_presentation_path(@deck)
    assert_response :success
    get full_presentation_presentation_downloads_path(@deck)
    assert_response :redirect
    assert_match %r{/rails/active_storage/disk/}, response.location
  end

  def assert_not_found_everywhere
    get presentation_path(@deck)
    assert_response :not_found
    get present_presentation_path(@deck)
    assert_response :not_found
    get full_presentation_presentation_downloads_path(@deck)
    assert_response :not_found
  end

  test "a direct owner still opens, presents and downloads an unpublished deck" do
    own(@owner, "direct")
    sign_in @owner
    assert_opens_everything
    get presentation_path(@deck)
    assert_no_match(/visible to admins only/, response.body)
    assert_match(/no longer in the library/, response.body)
  end

  test "a credit owner with an active membership still has it" do
    @owner.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    own(@owner, "credit")
    sign_in @owner
    assert_opens_everything
  end

  test "a lapsed credit owner has no access, as for a published deck, so the draft is a 404" do
    @owner.update!(subscription_status: "canceled", subscription_ends_at: 1.day.ago)
    own(@owner, "credit")
    sign_in @owner
    assert_not_found_everywhere
  end

  test "a signed-out visitor gets a 404" do
    assert_not_found_everywhere
  end

  test "a signed-in non-owner gets a 404" do
    sign_in users(:one)
    assert_not_found_everywhere
  end

  test "an admin still sees it, with the draft banner" do
    sign_in users(:admin)
    get presentation_path(@deck)
    assert_response :success
    assert_match(/Draft/, response.body)
  end

  # Each request in its own test: Devise's test sign-in rides on the next
  # request, and a 404 response does not keep the session for a second one.
  test "nobody can open the purchase page of an unpublished deck" do
    sign_in users(:one)
    get new_presentation_purchase_path(@deck)
    assert_response :not_found
  end

  test "nobody can buy an unpublished deck" do
    sign_in users(:one)
    assert_no_difference -> { UserPresentation.count } do
      post presentation_purchases_path(@deck), params: { purchase_method: "direct" }
    end
    assert_response :not_found
  end

  test "it is not in the library or the library search, even for its owner" do
    own(@owner, "direct")
    sign_in @owner
    get presentations_path
    assert_no_match "Pulled Deck", response.body
    get presentations_path(search: "Pulled")
    assert_no_match "Pulled Deck", response.body
  end

  test "the owners' account library still lists it" do
    own(@owner, "direct")
    sign_in @owner
    get account_path(tab: "library")
    assert_response :success
    assert_match "Pulled Deck", response.body
  end
end
