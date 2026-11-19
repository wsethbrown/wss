require "test_helper"

# B14 / I5: every external tool run (soffice, pdftoppm, pdftotext) is bounded
# by a timeout and each LibreOffice run gets its own profile directory, so a
# hung or parallel soffice can't wedge the jobs process or silently render
# nothing. An empty render is an error, never a quiet success.
class DeckImportTest < ActiveSupport::TestCase
  FIXTURE = Rails.root.join("test/fixtures/files/tiny_deck.pptx")

  test "parses the .pptx fixture inline into a draft" do
    result = DeckImport.parse(File.binread(FIXTURE), "tiny_deck.pptx")
    assert_equal "Fixture Deck", result.title
    assert_match(/## The Pour/, result.content)
    assert_match(/\ASlide 1\|The Pour\|Rye, neat\|/, result.slides_preview)
  end

  test "only .pptx text is parsed in the web request" do
    assert DeckImport.inline_parse?("deck.pptx")
    assert DeckImport.inline_parse?("DECK.PPTX")
    assert_not DeckImport.inline_parse?("deck.ppt")
    assert_not DeckImport.inline_parse?("deck.pdf")
  end

  test "run_tool kills a tool that runs past its timeout" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_raises(DeckImport::ToolTimeout) do
      DeckImport.run_tool("sleep", "30", timeout: 0.3)
    end
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  end

  test "run_tool reports the exit status and a missing tool" do
    assert DeckImport.run_tool("true", timeout: 5)
    assert_not DeckImport.run_tool("false", timeout: 5)
    assert_raises(DeckImport::ToolMissing) { DeckImport.run_tool("no-such-tool-b14", timeout: 5) }
  end

  test "each LibreOffice run gets its own profile directory and a timeout" do
    calls = []
    DeckImport.stubs(:run_tool).with { |*args| calls << args; true }.returns(true)
    Dir.mktmpdir { |a| DeckImport.convert_to_pdf(a, "x", ".ppt") }
    Dir.mktmpdir { |b| DeckImport.convert_to_pdf(b, "x", ".ppt") }

    profiles = calls.map { |args| args.grep(String).find { |arg| arg.start_with?("-env:UserInstallation=file://") } }
    assert_equal 2, profiles.compact.size
    assert_not_equal profiles.first, profiles.second
    calls.each do |args|
      assert_equal "soffice", args.first
      assert_equal({ timeout: DeckImport::SOFFICE_TIMEOUT }, args.last)
    end
  end

  test "a render that produces no slides raises instead of returning nothing" do
    DeckImport.stubs(:run_tool).returns(true) # tools "succeed" but write no files
    error = assert_raises(DeckImport::RenderError) { DeckImport.render_slides("%PDF-1.4", "deck.pdf") }
    assert_match(/no slides/i, error.message)
  end

  test "a conversion that produces no PDF raises" do
    DeckImport.stubs(:run_tool).returns(false)
    assert_raises(DeckImport::RenderError) { DeckImport.render_slides("junk", "deck.pptx") }
  end

  test "a missing render tool raises" do
    DeckImport.stubs(:run_tool).raises(DeckImport::ToolMissing, "soffice is not installed")
    assert_raises(DeckImport::RenderError) { DeckImport.render_slides("junk", "deck.pptx") }
  end

  # One real LibreOffice + poppler run, end to end, on a two-slide fixture.
  test "renders the .pptx fixture to one PNG per slide with real soffice" do
    skip "soffice/pdftoppm not installed" unless system("which soffice pdftoppm > /dev/null 2>&1")
    slides = DeckImport.render_slides(File.binread(FIXTURE), "tiny_deck.pptx")
    assert_equal 2, slides.size
    assert_equal slides.map { |s| s[:filename] }.sort, slides.map { |s| s[:filename] }
    slides.each { |s| assert s[:data].start_with?("\x89PNG".b), "#{s[:filename]} is not a PNG" }
  end
end
