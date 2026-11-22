require "test_helper"
require_relative "../../support/deck_package_fixture"

# Uploading a finished deck package (.zip) from the admin: "Upload a package"
# creates a new draft deck; "Replace with a package" on a deck updates that
# deck in place, whatever its title.
class Admin::DeckPackagesControllerTest < ActionDispatch::IntegrationTest
  include DeckPackageFixture

  setup do
    @work = Dir.mktmpdir("deck-packages-controller")
    @package = build_deck_package(File.join(@work, "package"))
    @zip = zip_deck_package(@package, File.join(@work, "test-deck.zip"), folder: "test-deck")
    sign_in users(:admin)
  end

  teardown { FileUtils.remove_entry(@work) }

  def upload(path = @zip, type = "application/zip")
    Rack::Test::UploadedFile.new(path, type, true)
  end

  def live_deck
    deck = Presentation.create!(author: users(:john), title: "An Old Title", content: "Old story.", price: 24)
    deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 old"), filename: "old.pdf", content_type: "application/pdf")
    deck.slide_images.attach(io: File.open(Rails.root.join("test/fixtures/files/slides/slide-09.png"), "rb"),
                             filename: "old.png", content_type: "image/png")
    deck.update!(published: true)
    deck
  end

  test "the upload page renders from the deck list" do
    get admin_presentations_path
    assert_select "a[href=?]", new_admin_deck_package_path, text: "Upload a package"
    get new_admin_deck_package_path
    assert_response :success
    assert_select "form[action=?][enctype='multipart/form-data'] input[type=file][name=package]", admin_deck_packages_path
  end

  test "uploading a package creates a draft deck and lands on its page with a summary" do
    assert_difference -> { Presentation.count }, 1 do
      post admin_deck_packages_path, params: { package: upload }
    end
    deck = Presentation.order(:id).last
    assert_redirected_to admin_presentation_path(deck)
    assert_equal "Test Deck", deck.title
    assert_not deck.published?
    assert_equal 3, deck.slide_images.count

    follow_redirect!
    assert_select "#package-summary" do
      assert_select "*", text: /3 slides/
      assert_select "*", text: /2 pours/
      assert_select "*", text: /Draft/
      assert_select "*", text: /\$19\.99/
      assert_select "*", text: /Research outline/
      assert_select "a[href=?]", presentation_path(deck)
    end
  end

  test "a package whose title is taken is refused, pointing at Replace with a package on that deck" do
    existing = live_deck
    existing.update!(title: "Test Deck")
    assert_no_difference -> { Presentation.count } do
      post admin_deck_packages_path, params: { package: upload }
    end
    assert_response :unprocessable_entity
    assert_match(/already exists/, response.body)
    assert_select "a[href=?]", new_admin_presentation_package_path(existing)
    assert_equal "Old story.", existing.reload.content
  end

  test "replacing updates that deck in place, whatever its title, and keeps price and published" do
    deck = live_deck
    get admin_presentation_path(deck)
    assert_select "a[href=?]", new_admin_presentation_package_path(deck), text: "Replace with a package"
    get new_admin_presentation_package_path(deck)
    assert_response :success
    assert_select "form[action=?]", admin_presentation_package_path(deck)

    assert_no_difference -> { Presentation.count } do
      post admin_presentation_package_path(deck), params: { package: upload }
    end
    assert_redirected_to admin_presentation_path(deck)
    deck.reload
    assert_equal "Test Deck", deck.title
    assert_equal BigDecimal("24"), deck.price
    assert deck.published?
    assert_equal 3, deck.slide_images.count
    follow_redirect!
    assert_select "#package-summary", text: /Published/
  end

  test "a file that is not a zip is refused in plain words, and the deck is untouched" do
    deck = live_deck
    post admin_presentation_package_path(deck),
         params: { package: upload(Rails.root.join("test/fixtures/files/sample_review.txt"), "text/plain") }
    assert_response :unprocessable_entity
    assert_match(/isn&#39;t a zip|isn't a zip/, response.body)
    assert_equal "An Old Title", deck.reload.title
  end

  test "a zip that is not a package says so" do
    path = File.join(@work, "not-a-package.zip")
    Zip::File.open(path, create: true) { |z| z.get_output_stream("notes.md") { |f| f.write("hi") } }
    post admin_deck_packages_path, params: { package: upload(path) }
    assert_response :unprocessable_entity
    assert_match(/deck\.json/, response.body)
  end

  test "a package missing its deck file names the file" do
    FileUtils.rm(File.join(@package, "Test-Deck.pptx"))
    zip = zip_deck_package(@package, File.join(@work, "missing.zip"))
    assert_no_difference -> { Presentation.count } do
      post admin_deck_packages_path, params: { package: upload(zip) }
    end
    assert_response :unprocessable_entity
    assert_match(/Test-Deck\.pptx/, response.body)
  end

  test "posting with no file asks for one" do
    post admin_deck_packages_path
    assert_response :unprocessable_entity
    assert_match(/Choose the package/, response.body)
  end

  test "a slide count that differs from the script is a warning on the summary, not a refusal" do
    File.write(File.join(@package, "speaker-notes.md"), "---\n\n## [SLIDE 1] One\n\nHi.\n")
    zip = zip_deck_package(@package, File.join(@work, "mismatch.zip"))
    post admin_deck_packages_path, params: { package: upload(zip) }
    follow_redirect!
    assert_select "#package-summary", text: /1 \[SLIDE n\] section/
  end

  test "a limited admin can upload, like the neighbouring deck actions" do
    delete destroy_user_session_path
    sign_in users(:limited_admin)
    assert_difference -> { Presentation.count }, 1 do
      post admin_deck_packages_path, params: { package: upload }
    end
  end

  test "a non-admin cannot upload or replace" do
    deck = live_deck
    delete destroy_user_session_path
    sign_in users(:john)
    assert_no_difference -> { Presentation.count } do
      post admin_deck_packages_path, params: { package: upload }
    end
    assert_response :redirect
    post admin_presentation_package_path(deck), params: { package: upload }
    assert_equal "An Old Title", deck.reload.title
    get new_admin_deck_package_path
    assert_response :redirect
  end

  test "signed out is sent away" do
    delete destroy_user_session_path
    post admin_deck_packages_path, params: { package: upload }
    assert_response :redirect
    assert_nil Presentation.find_by(title: "Test Deck")
  end
end
