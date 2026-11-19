require "test_helper"

# B9 / S5: paid files are never handed out by a permanent signed-id URL. After
# the access check the owner is redirected to a short-lived service URL.
class Presentations::DownloadsControllerTest < ActionDispatch::IntegrationTest
  OWNER_ACTIONS = {
    full_presentation: :pdf_file,
    speaker_notes: :speaker_notes,
    outline: :outline_file,
    recommendations: :recommendations_sheet,
    scorecard: :scorecard
  }.freeze

  setup do
    @user = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Download Deck", content: "Story.", price: 15)
    @deck.update_column(:published, true)
    OWNER_ACTIONS.each_value do |att|
      @deck.public_send(att).attach(io: StringIO.new("%PDF-1.4 #{att}"), filename: "#{att}.pdf", content_type: "application/pdf")
    end
    @deck.sneak_peek_file.attach(io: StringIO.new("%PDF-1.4 peek"), filename: "peek.pdf", content_type: "application/pdf")
  end

  def own(type)
    UserPresentation.create!(user: @user, presentation: @deck, purchase_type: type, purchased_at: Time.current)
  end

  def activate!
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
  end

  def lapse!
    @user.update!(subscription_status: "canceled", subscription_ends_at: 1.day.ago)
  end

  def download_path(action)
    public_send("#{action}_presentation_downloads_path", @deck)
  end

  def assert_short_lived_service_url
    assert_response :redirect
    location = response.location
    assert_no_match %r{/rails/active_storage/blobs/redirect/}, location, "must not be the permanent signed-id URL"
    assert_match %r{/rails/active_storage/disk/}, location, "must be a service URL"
    token = location[%r{/disk/([^/]+)/}, 1]
    payload = ActiveStorage.verifier.verified(token, purpose: :blob_key)
    assert_match(/\Aattachment/, payload["disposition"] || payload[:disposition], "must force a download")
  end

  OWNER_ACTIONS.each_key do |action|
    test "#{action}: signed out is sent to sign in" do
      get download_path(action)
      assert_redirected_to auth_path
    end

    test "#{action}: member without ownership is sent to purchase" do
      sign_in @user
      get download_path(action)
      assert_redirected_to new_presentation_purchase_path(@deck)
    end

    test "#{action}: lapsed credit owner is sent to pricing" do
      lapse!
      own("credit")
      sign_in @user
      get download_path(action)
      assert_redirected_to root_path(anchor: "pricing")
    end

    test "#{action}: active credit owner gets a short-lived service URL" do
      activate!
      own("credit")
      sign_in @user
      get download_path(action)
      assert_short_lived_service_url
    end

    test "#{action}: direct owner gets a short-lived service URL even when lapsed" do
      lapse!
      own("direct")
      sign_in @user
      get download_path(action)
      assert_short_lived_service_url
    end

    test "#{action}: admin gets a short-lived service URL" do
      sign_in users(:admin)
      get download_path(action)
      assert_short_lived_service_url
    end

    test "#{action}: logs the download for the owner" do
      own("direct")
      sign_in @user
      assert_difference -> { DownloadLog.where(user: @user, file_type: action.to_s).count }, 1 do
        get download_path(action)
      end
    end
  end

  test "blank_scorecard downloads are logged" do
    own("direct")
    sign_in @user
    assert_difference -> { DownloadLog.where(user: @user, file_type: "blank_scorecard").count }, 1 do
      get download_path(:blank_scorecard)
    end
  end

  test "a failing audit write is logged at error with ids and does not block the download" do
    own("direct")
    sign_in @user
    DownloadLog.stubs(:create!).raises(ActiveRecord::RecordInvalid.new(DownloadLog.new))
    Rails.logger.expects(:error).with(regexp_matches(/user #{@user.id} presentation #{@deck.id} file outline/))
    get download_path(:outline)
    assert_response :redirect
  end

  test "full_presentation increments the download count" do
    own("direct")
    sign_in @user
    assert_difference -> { @deck.reload.download_count.to_i }, 1 do
      get download_path(:full_presentation)
    end
  end

  test "the service URL actually serves the file as an attachment, then expires" do
    own("direct")
    sign_in @user
    get download_path(:outline)
    get response.location
    assert_response :success
    assert_match(/attachment/, response.headers["Content-Disposition"])
    assert_equal "%PDF-1.4 outline_file", response.body
  end

  test "the service URL expires" do
    own("direct")
    sign_in @user
    get download_path(:outline)
    token = response.location[%r{/disk/([^/]+)/}, 1]
    assert ActiveStorage.verifier.verified(token, purpose: :blob_key)
    travel 6.minutes do
      assert_nil ActiveStorage.verifier.verified(token, purpose: :blob_key)
    end
  end

  test "scorecard falls back to the blank card when none is attached" do
    @deck.scorecard.purge
    own("direct")
    sign_in @user
    get download_path(:scorecard)
    assert_redirected_to blank_scorecard_presentation_downloads_path(@deck)
  end

  test "blank_scorecard is a direct file for owners and refused otherwise" do
    get download_path(:blank_scorecard)
    assert_redirected_to auth_path

    own("direct")
    sign_in @user
    get download_path(:blank_scorecard)
    assert_response :success
    assert_equal "application/pdf", response.media_type
  end

  test "sneak_peek is public, signed out, and unchanged" do
    get download_path(:sneak_peek)
    assert_response :redirect
    assert_match %r{/rails/active_storage/blobs/redirect/}, response.location
  end

  test "a missing file redirects back to the deck" do
    @deck.outline_file.purge
    own("direct")
    sign_in @user
    get download_path(:outline)
    assert_redirected_to presentation_path(@deck)
  end

  test "drafts 404 for non-admins" do
    @deck.update_column(:published, false)
    own("direct")
    sign_in @user
    get download_path(:outline)
    assert_response :not_found
  end
end
