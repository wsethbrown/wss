require "test_helper"

# "Open" on the admin deck page: an admin opens any of a deck's files, whoever
# owns the deck, by slot name. Only the named slots are served; there is no
# way to ask for an arbitrary blob.
class Admin::PresentationFilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @deck = Presentation.create!(author: users(:john), title: "Someone Else's Deck", content: "x", price: 5)
    @deck.speaker_notes.attach(io: StringIO.new("%PDF-1.4 notes"), filename: "notes.pdf", content_type: "application/pdf")
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 deck"), filename: "deck.pdf", content_type: "application/pdf")
  end

  # Rails.logger is what the controllers write to; collect what it is told.
  def capture_log
    io = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = original
  end

  test "an admin opens a deck's file by slot, and it is logged with the ids" do
    sign_in users(:limited_admin)
    log = capture_log { get admin_presentation_file_path(@deck, "speaker_notes") }
    assert_response :redirect
    assert_match %r{/rails/active_storage/}, response.location
    assert_match(/Admin #{users(:limited_admin).id} opened presentation #{@deck.id} file speaker_notes/, log)
    assert_no_match(/notes\.pdf|PDF-1\.4/, log, "no file names or contents in the log")
  end

  %w[pdf_file speaker_notes].each do |slot|
    test "the #{slot} slot opens" do
      sign_in users(:admin)
      get admin_presentation_file_path(@deck, slot)
      assert_response :redirect
      assert_match %r{/rails/active_storage/}, response.location
    end
  end

  test "an extra opens by its place in the list, scoped to this deck" do
    @deck.supplemental_materials.attach(io: StringIO.new("%PDF-1.4 mat"), filename: "mat.pdf", content_type: "application/pdf")
    sign_in users(:admin)
    get admin_presentation_file_path(@deck, "supplemental_materials", n: 1)
    assert_match %r{/rails/active_storage/}, response.location
    get admin_presentation_file_path(@deck, "supplemental_materials", n: 2)
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "files")
  end

  test "a slot that is not on the list is refused and logged" do
    sign_in users(:admin)
    log = capture_log { get admin_presentation_file_path(@deck, "slide_images") }
    assert_response :not_found
    assert_match(/refused/, log)
    get admin_presentation_file_path(@deck, "author")
    assert_response :not_found
  end

  test "an empty slot sends the admin back to the files tab" do
    sign_in users(:admin)
    log = capture_log { get admin_presentation_file_path(@deck, "outline_file") }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "files")
    assert flash[:alert].present?
    assert_match(/outline_file.*not attached|not attached.*outline_file/, log)
  end

  test "a member who is not an admin cannot open a file here" do
    sign_in users(:jane)
    get admin_presentation_file_path(@deck, "speaker_notes")
    assert_redirected_to root_path
  end

  test "a signed-out visitor cannot open a file here" do
    get admin_presentation_file_path(@deck, "speaker_notes")
    assert_response :redirect
    assert_no_match %r{/rails/active_storage/}, response.location.to_s
  end
end
