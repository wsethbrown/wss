require "test_helper"

# B14 / I4: .ppt and .pdf text extraction (LibreOffice / pdftotext) runs in
# this job on the renders queue, never in the web request. It fills the draft
# only where the admin hasn't already edited the imported placeholder.
class DeckImportJobTest < ActiveJob::TestCase
  setup do
    placeholder = DeckImport.placeholder("Old_Fashioned.ppt")
    @deck = Presentation.create!(author: users(:admin), price: 0, published: false,
                                 title: placeholder.title, description: placeholder.description,
                                 content: placeholder.content, slides_preview: placeholder.slides_preview)
    @deck.pdf_file.attach(io: StringIO.new("ppt bytes"), filename: "Old_Fashioned.ppt",
                          content_type: "application/vnd.ms-powerpoint")
    @parsed = DeckImport::Result.new(title: "The Old Fashioned", description: "Sugar, bitters, rye",
                                     content: "## History\n\nIt began in Louisville.",
                                     slides_preview: "Slide 1|History|It began in Louisville.|", images: [])
  end

  test "runs on the renders queue" do
    assert_equal "renders", DeckImportJob.new.queue_name
  end

  test "fills the untouched draft from the extracted text" do
    DeckImport.expects(:parse).with("ppt bytes", "Old_Fashioned.ppt").returns(@parsed)
    DeckImportJob.perform_now(@deck.id)
    @deck.reload
    assert_equal "The Old Fashioned", @deck.title
    assert_equal "Sugar, bitters, rye", @deck.description
    assert_match(/Louisville/, @deck.content)
    assert_equal "Slide 1|History|It began in Louisville.|", @deck.slides_preview
  end

  test "never overwrites a field the admin already edited" do
    @deck.update!(title: "My own title", content: "My own story.")
    DeckImport.stubs(:parse).returns(@parsed)
    DeckImportJob.perform_now(@deck.id)
    @deck.reload
    assert_equal "My own title", @deck.title
    assert_equal "My own story.", @deck.content
    assert_equal "Sugar, bitters, rye", @deck.description
  end

  test "a timed-out extraction is logged and raised, leaving the draft as it was" do
    log = StringIO.new
    old = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(log)
    DeckImport.stubs(:parse).raises(DeckImport::ToolTimeout, "soffice timed out after 180s")
    assert_raises(DeckImport::ToolTimeout) { DeckImportJob.perform_now(@deck.id) }
    assert_equal "Old Fashioned", @deck.reload.title
    assert_match(/text extraction failed for deck #{@deck.id}: DeckImport::ToolTimeout/, log.string)
  ensure
    Rails.logger = old
  end
end
