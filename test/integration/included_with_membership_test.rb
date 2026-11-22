require "test_helper"
require_relative "../support/deck_package_fixture"

# Decks flagged included_with_membership open for any member with an active
# membership, with no credit spent and no purchase. Everyone else pays the
# price. Access ends with the membership, exactly like a credit unlock, and no
# ownership row or ledger row is ever written for it.
class IncludedWithMembershipTest < ActionDispatch::IntegrationTest
  include DeckPackageFixture

  setup do
    @user = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Included Deck", content: "Story.", price: 15,
                                 included_with_membership: true)
    @deck.update_column(:published, true)
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 deck"), filename: "deck.pdf", content_type: "application/pdf")
  end

  def activate!
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
  end

  def lapse!
    @user.update!(subscription_status: "canceled", subscription_ends_at: 1.day.ago)
  end

  def capture_log
    io = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = old
  end

  # --- The access rule ---------------------------------------------------

  test "the flag defaults to off" do
    assert_not Presentation.new.included_with_membership?
  end

  test "an active member opens an included deck without owning it, and it is logged" do
    activate!
    log = capture_log { assert @user.can_access_presentation?(@deck.id) }
    assert @deck.can_download_full_presentation?(@user)
    assert_match(/user #{@user.id}\b.*presentation #{@deck.id}\b.*included with membership/, log)
    assert_no_match(/@/, log.lines.grep(/included with membership/).join)
  end

  test "a non-member and a lapsed member have no access" do
    assert_not @user.can_access_presentation?(@deck.id)
    lapse!
    assert_not @user.can_access_presentation?(@deck.id)
  end

  test "a deck without the flag still needs a purchase or a credit" do
    activate!
    @deck.update!(included_with_membership: false)
    assert_not @user.can_access_presentation?(@deck.id)
  end

  # --- Deck page, downloads, purchase page -------------------------------

  test "a member sees it as included and opens the deck file; nothing is bought or spent" do
    activate!
    CreditTransaction.record!(user: @user, amount: 1, transaction_type: "granted")
    sign_in @user

    assert_no_difference [ "UserPresentation.count", "CreditTransaction.count" ] do
      get presentation_path(@deck)
      assert_response :success
      assert_match "Included with your membership", response.body
      assert_select "a[href=?]", full_presentation_presentation_downloads_path(@deck)

      get full_presentation_presentation_downloads_path(@deck)
      assert_response :redirect
      assert_no_match(/purchase|membership/, response.location)

      get new_presentation_purchase_path(@deck)
      assert_redirected_to presentation_path(@deck)
      post presentation_purchases_path(@deck), params: { purchase_method: "credit" }
      assert_redirected_to presentation_path(@deck)
    end
    assert_equal 1, @user.reload.credits
  end

  test "a non-member sees the price with the included note and is sent to buy it" do
    sign_in @user
    get presentation_path(@deck)
    assert_response :success
    assert_match @deck.formatted_price, response.body
    assert_match "Included with membership", response.body
    assert_no_match "Included with your membership", response.body

    get full_presentation_presentation_downloads_path(@deck)
    assert_redirected_to new_presentation_purchase_path(@deck)

    get new_presentation_purchase_path(@deck)
    assert_response :success
  end

  test "a lapsed member loses access again" do
    lapse!
    sign_in @user
    get full_presentation_presentation_downloads_path(@deck)
    assert_redirected_to new_presentation_purchase_path(@deck)
  end

  # --- Unpublished decks ------------------------------------------------------

  test "an unpublished included deck gives an active member no page, no Present and no downloads" do
    @deck.update_column(:published, false)
    @deck.slide_images.attach(io: File.open(Rails.root.join("test/fixtures/files/slides/slide-01.png"), "rb"),
                              filename: "slide-01.png", content_type: "image/png")
    activate!
    assert_not @user.can_access_presentation?(@deck.id)
    assert_not @deck.included_for?(@user)
    assert_not @deck.visible_to?(@user)

    sign_in @user
    get presentation_path(@deck)
    assert_response :not_found
    get present_presentation_path(@deck)
    assert_response :not_found
    get full_presentation_presentation_downloads_path(@deck)
    assert_response :not_found
  end

  test "a member loses access when an included deck is unpublished" do
    activate!
    assert @user.can_access_presentation?(@deck.id)
    @deck.update_column(:published, false)
    assert_not @user.can_access_presentation?(@deck.id)
    assert_not @deck.reload.can_download_full_presentation?(@user)
  end

  test "an admin keeps access to an unpublished included deck" do
    @deck.update_column(:published, false)
    assert @deck.can_download_full_presentation?(users(:admin))
  end

  # --- The library ---------------------------------------------------------

  test "the library card says included for a member and shows the price otherwise" do
    sign_in @user
    get presentations_path
    assert_select "article", text: /Included Deck.*\$15\.00/m

    activate!
    get presentations_path
    assert_select "article", text: /Included Deck.*Included with your membership/m
  end

  # --- Admin and the importer ---------------------------------------------

  test "the admin sets the flag on the deck page next to the price" do
    @deck.update!(included_with_membership: false)
    sign_in users(:admin)
    get edit_admin_presentation_path(@deck)
    assert_select "input[type=checkbox][name=?]", "presentation[included_with_membership]"
    assert_match "Included with membership", response.body
    assert_match "Members open this deck without spending a credit. Everyone else pays the price.", response.body

    patch admin_presentation_path(@deck), params: { presentation: { included_with_membership: "1" } }
    assert @deck.reload.included_with_membership?
  end

  test "replacing a deck from a package leaves the flag alone" do
    dir = build_deck_package(Dir.mktmpdir("included-package"))
    DeckPackageImport.call(dir, author: users(:admin), into: @deck)
    assert @deck.reload.included_with_membership?
  ensure
    FileUtils.remove_entry(dir) if dir
  end
end
