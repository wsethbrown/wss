require "test_helper"

# B14 / I4: importing a .ppt or .pdf creates the draft at once and never runs
# LibreOffice or pdftotext inside the web request; the text is extracted by
# DeckImportJob. A .pptx is still parsed inline (pure XML, no tools).
class Admin::PresentationsImportTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in users(:admin) }

  def upload(name, type)
    Rack::Test::UploadedFile.new(StringIO.new("not really a deck"), type, true, original_filename: name)
  end

  %w[.ppt .pdf].each do |ext|
    test "a #{ext} import does not run soffice or pdftotext in-process" do
      DeckImport.expects(:run_tool).never
      DeckImport.expects(:parse).never
      Process.expects(:spawn).never
      Kernel.expects(:system).never

      assert_difference -> { Presentation.count }, 1 do
        assert_enqueued_with(job: DeckImportJob) do
          assert_enqueued_with(job: DeckSlideRenderJob) do
            post import_admin_presentations_path,
                 params: { deck_file: upload("Old_Fashioned#{ext}", DeckImport.content_type_for("x#{ext}")) }
          end
        end
      end
      deck = Presentation.order(:id).last
      assert_redirected_to edit_admin_presentation_path(deck)
      assert_equal "Old Fashioned", deck.title
      assert_not deck.published?
      assert deck.pdf_file.attached?
    end
  end

  test "a .pptx import is parsed inline and queues only the render" do
    file = Rack::Test::UploadedFile.new(Rails.root.join("test/fixtures/files/tiny_deck.pptx"),
                                        DeckImport.content_type_for("x.pptx"))
    post import_admin_presentations_path, params: { deck_file: file }
    deck = Presentation.order(:id).last
    assert_equal "Fixture Deck", deck.title
    assert_enqueued_jobs 1, only: DeckSlideRenderJob
    assert_enqueued_jobs 0, only: DeckImportJob
  end
end
