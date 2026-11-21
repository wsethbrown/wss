require "test_helper"

# Site admins have access to every deck without buying it; the deck page must
# show the owner tools (Present/Open/Downloads) instead of the price pitch, and
# must not change anything for anyone else.
class PresentationsAdminAccessTest < ActionDispatch::IntegrationTest
  FILES = {
    full_presentation: :pdf_file,
    speaker_notes: :speaker_notes,
    outline: :outline_file,
    recommendations: :recommendations_sheet,
    scorecard: :scorecard
  }.freeze

  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Admin Deck", content: "Story.\n\nMore story.", price: 17.99)
    @deck.update_column(:published, true)
    FILES.each_value do |att|
      @deck.public_send(att).attach(io: StringIO.new("%PDF-1.4 #{att}"), filename: "#{att}.pdf", content_type: "application/pdf")
    end
  end

  def download_hrefs
    FILES.keys.map { |a| public_send("#{a}_presentation_downloads_path", @deck) } +
      [ blank_scorecard_presentation_downloads_path(@deck) ]
  end

  def assert_owner_tools
    assert_select "#deck-downloads"
    download_hrefs.each { |href| assert_select "a[href=?]", href }
    assert_select "a[href=?]", full_presentation_presentation_downloads_path(@deck), text: /Open the deck/
    assert_select "a[href='#deck-story']", text: /Read the story/
  end

  def assert_no_owner_tools
    assert_select "#deck-downloads", count: 0
    download_hrefs.each { |href| assert_select "a[href=?]", href, count: 0 }
  end

  %i[admin limited_admin].each do |who|
    test "#{who} with no purchase sees owner tools and no purchase pitch" do
      sign_in users(who)
      get presentation_path(@deck)
      assert_response :success

      assert_owner_tools
      assert_select "#deck-actions", text: /Admin access/
      assert_select "#deck-actions", text: /You can open every deck as a site admin\. Customers see the price and purchase options here\./
      assert_select "a[href=?]", new_presentation_purchase_path(@deck), count: 0
      assert_select "#deck-actions", text: /What you get/, count: 0
      assert_no_match(/\$17\.99/, css_select("#deck-actions").to_s)
    end
  end

  test "an admin who bought the deck sees the normal owner state" do
    UserPresentation.create!(user: users(:admin), presentation: @deck, purchase_type: "direct", purchased_at: Time.current)
    sign_in users(:admin)
    get presentation_path(@deck)

    assert_owner_tools
    assert_select "#deck-actions", text: /Yours for good/
    assert_select "#deck-actions", text: /Admin access/, count: 0
  end

  test "a signed-in non-admin non-owner still sees the purchase link and no downloads" do
    sign_in users(:jane)
    get presentation_path(@deck)
    assert_response :success

    assert_select "a[href=?]", new_presentation_purchase_path(@deck), text: /Purchase/
    assert_select "#deck-actions", text: /Admin access/, count: 0
    assert_no_owner_tools
  end

  test "a lapsed credit owner still gets no downloads" do
    user = users(:john)
    user.update!(subscription_status: "canceled", subscription_ends_at: 1.day.ago)
    UserPresentation.create!(user: user, presentation: @deck, purchase_type: "credit", purchased_at: Time.current)
    sign_in user
    get presentation_path(@deck)
    assert_response :success

    assert_select "#deck-actions", text: /Membership paused/
    assert_select "a[href=?]", membership_path(anchor: "pricing"), text: /Reactivate membership/
    assert_no_owner_tools
  end

  test "an admin sees the owner tools on a draft deck" do
    @deck.update_column(:published, false)
    sign_in users(:admin)
    get presentation_path(@deck)
    assert_response :success

    assert_owner_tools
    assert_select "#deck-actions", text: /Admin access/
  end
end
