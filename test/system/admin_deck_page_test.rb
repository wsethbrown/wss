require "application_system_test_case"

# The admin deck page in a real browser: the six tabs (deck-tabs) and the
# slide viewer with its script search (slide-viewer).
class AdminDeckPageTest < ApplicationSystemTestCase
  SLIDE = Rails.root.join("test/fixtures/files/slides/slide-01.png")

  setup do
    @admin = users(:admin)
    @deck = Presentation.create!(author: @admin, title: "System Deck", content: "A story.", price: 12)
    3.times do |i|
      @deck.slide_images.attach(io: File.open(SLIDE, "rb"), filename: "slide-#{i + 1}.png", content_type: "image/png")
    end
    @deck.update_columns(slide_script: [
      { "title" => "Welcome", "body" => "Hold up the julep cup." },
      { "title" => "Glass A", "body" => "Pour the brandy now." },
      { "title" => "Goodnight", "body" => "Thanks for coming." }
    ])
    PresentationBottle.create!(presentation: @deck, name: "Woodford Reserve", price: "$40", position: 1)
  end

  def sign_in_admin
    visit_sign_in_page
    fill_in "magic-link-email", with: @admin.email
    find("#password-toggle").click
    fill_in "signin-password", with: "password"
    within("#password-signin") { click_button "Sign in" }
    assert_link "Sign out"
  end

  test "tabs switch panes and remember the tab in the address" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck)

    assert_selector "[role=tab][aria-selected=true]", text: "Overview"
    assert_selector "#pane-overview", visible: true
    assert_selector "#pane-pours", visible: :hidden

    click_on "Pour list"
    assert_selector "#pane-pours", visible: true
    assert_selector "#pane-overview", visible: :hidden
    assert_equal "#pours", page.evaluate_script("location.hash")
    assert_equal "pours", find("#deck-tab", visible: :all).value

    visit edit_admin_presentation_path(@deck, anchor: "files")
    assert_selector "[role=tab][aria-selected=true]", text: "Files"
    assert_selector "#pane-files", visible: true
  end

  test "the slide viewer steps through slides and finds words in the script" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck, anchor: "slides")

    assert_text "Slide 1 of 3"
    assert_selector "[data-slide-viewer-target=script]", text: "Hold up the julep cup."
    assert_no_selector "[data-slide-viewer-target=script]", text: "Pour the brandy now."

    click_on "Next →"
    assert_text "Slide 2 of 3"
    assert_selector "[data-slide-viewer-target=script]", text: "Pour the brandy now."

    find("body").send_keys(:right)
    assert_text "Slide 3 of 3"
    find("body").send_keys(:left)
    assert_text "Slide 2 of 3"

    fill_in "Find in the script", with: "julep"
    assert_text "1 of 3 slides"
    assert_text "Slide 1 of 3"
    assert_selector "[data-slide-viewer-target=script] mark", text: "julep"

    fill_in "Find in the script", with: "nothing like this"
    assert_text "No slide mentions that"
  end

  # --- Unsaved edits ---

  LEAVE = "Your changes to this deck are not saved. Continue without saving them?"

  def edit_running_time(to)
    click_on "Listing"
    fill_in "Running time", with: to
  end

  # WebDriver accepts the browser's own leave prompt (beforeunload) by itself,
  # so it can't be dismissed from a test. What can be checked is that the
  # link became a real page load and the page asked for the prompt.
  test "with unsaved edits, following a link asks for the browser's own leave prompt" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck)
    edit_running_time("99")
    page.execute_script(<<~JS)
      sessionStorage.removeItem("leavePrompt")
      window.addEventListener("beforeunload", e => sessionStorage.setItem("leavePrompt", String(e.defaultPrevented)))
    JS

    click_on "← Decks"
    assert_current_path admin_presentations_path
    assert_equal "true", page.evaluate_script("sessionStorage.getItem('leavePrompt')")
    assert_nil @deck.reload.duration
  end

  test "with no edits, following a link does not ask" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck)
    page.execute_script(<<~JS)
      sessionStorage.removeItem("leavePrompt")
      window.addEventListener("beforeunload", e => sessionStorage.setItem("leavePrompt", String(e.defaultPrevented)))
    JS
    click_on "← Decks"
    assert_current_path admin_presentations_path
    assert_nil page.evaluate_script("sessionStorage.getItem('leavePrompt')"), "a Turbo visit, no unload at all"
  end

  test "Save never asks" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck)
    edit_running_time("99")
    first(:button, "Save deck").click
    assert_text "Presentation updated successfully."
    assert_equal "99", @deck.reload.duration
  end

  test "with unsaved edits, Delete still asks its own question, once" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck)
    edit_running_time("99")
    click_on "Overview"

    message = dismiss_confirm { click_button "Delete" }
    assert_equal "Are you sure you want to delete this deck?", message
    assert Presentation.exists?(@deck.id)

    accept_confirm("Are you sure you want to delete this deck?") { click_button "Delete" }
    assert_current_path admin_presentations_path
    assert_not Presentation.exists?(@deck.id)
  end

  test "with unsaved edits, a form with no question of its own asks before it runs" do
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
    sign_in_admin
    visit edit_admin_presentation_path(@deck)
    edit_running_time("99")
    click_on "Files"

    message = dismiss_confirm { within("[data-pane=files]:not(#pane-files)") { click_button "Re-render slide previews" } }
    assert_equal LEAVE, message
    assert_no_text "Slide render queued"
    click_on "Listing"
    assert_field "Running time", with: "99"
  end

  # Back and Forward are not guarded (holding Turbo's render froze the page).
  # This pins that Back with edits leaves Turbo working: the next save lands.
  test "after Back with unsaved edits, the deck page still saves" do
    sign_in_admin
    visit admin_presentations_path
    click_on "System Deck"
    assert_selector "h1", text: "System Deck"
    edit_running_time("99")

    page.go_back
    assert_current_path admin_presentations_path
    click_on "System Deck"
    # Turbo shows its cached copy of the page first; type into the real one.
    assert_no_selector "html[data-turbo-preview]", visible: :all
    assert_field "Running time", with: "", visible: :all
    edit_running_time("77")
    first(:button, "Save deck").click
    assert_text "Presentation updated successfully."
    assert_equal "77", @deck.reload.duration
  end

  test "Replace reveals the file field" do
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
    sign_in_admin
    visit edit_admin_presentation_path(@deck, anchor: "files")

    within(".file-row", text: "Deck file") do
      assert_no_selector "input[type=file]"
      click_button "Replace"
      assert_selector "input[type=file][name='presentation[pdf_file]']", visible: true
    end
  end

  # --- Listing: "What the customer sees" and the extra sections ---

  test "typing in a Listing field updates what the customer sees, without saving" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck, anchor: "listing")
    within_frame("customer-preview") { assert_selector "h1", text: "System Deck" }

    fill_in "presentation_description", with: "A pitch typed just now."
    within_frame("customer-preview") do
      assert_text "A pitch typed just now."
      assert_selector "h1", text: "System Deck"
    end
    assert_selector "form#deck-form[data-unsaved-changes-dirty-value=true]", visible: :all
    assert_nil @deck.reload.description, "the preview saves nothing"
  end

  test "sections are added, reordered and shown in the preview, then saved in that order" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck, anchor: "listing")

    click_on "Add a section"
    within all("#f-sections .section-item").last do
      find(".section-heading").fill_in(with: "On the night")
      find(".section-lines").fill_in(with: "Glass A: first\nGlass B: later")
    end
    click_on "Add a section"
    within all("#f-sections .section-item").last do
      find(".section-heading").fill_in(with: "Who it's for")
      find(".section-lines").fill_in(with: "New to rye.")
      find("button[aria-label='Move up']").click
    end

    within_frame("customer-preview") do
      assert_selector "[data-deck-section]", count: 2
      assert_equal [ "Who it's for", "On the night" ], all("[data-deck-section] h2").map(&:text)
      assert_selector "[data-deck-section] li", text: "Glass A"
    end

    first(:button, "Save deck").click
    assert_text "Presentation updated successfully."
    assert_equal [ { "heading" => "Who it's for", "lines" => [ "New to rye." ] },
                   { "heading" => "On the night", "lines" => [ "Glass A: first", "Glass B: later" ] } ], @deck.reload.sections

    click_on "Listing"
    within all("#f-sections .section-item").first do
      find("button[aria-label='Remove section']").click
    end
    within_frame("customer-preview") { assert_selector "[data-deck-section]", count: 1 }
    # The first save's message is still on the page, so it can't show that
    # this save finished. Mark this page; the save's redirect renders a new
    # body without the mark.
    page.execute_script("document.body.dataset.beforeSecondSave = 'true'")
    first(:button, "Save deck").click
    assert_no_selector "body[data-before-second-save]"
    assert_text "Presentation updated successfully."
    assert_equal [ "On the night" ], @deck.reload.sections.map { |section| section["heading"] }
  end

  test "a field the browser refuses on a hidden tab opens that tab instead of blocking Save silently" do
    sign_in_admin
    visit edit_admin_presentation_path(@deck, anchor: "slides")
    find("input[name='presentation[preview_slide_count]']").fill_in(with: "0")
    click_on "Listing"
    assert_selector "#pane-slides", visible: :hidden

    first(:button, "Save deck").click
    assert_selector "#pane-slides", visible: true
    assert_selector "[role=tab][aria-selected=true]", text: "Slides and script"
    assert_equal 3, @deck.reload.preview_slide_count
  end
end
