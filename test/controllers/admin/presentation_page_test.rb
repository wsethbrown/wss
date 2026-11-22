require "test_helper"
require_relative "../../support/deck_package_fixture"

# One page per deck: /admin/presentations/:id/edit holds everything an admin
# reads or changes about a deck, in six tabs, under a header that always shows
# the deck's state. The old view page (show) now redirects here.
class Admin::PresentationPageTest < ActionDispatch::IntegrationTest
  include DeckPackageFixture

  SLIDE = Rails.root.join("test/fixtures/files/slides/slide-01.png")

  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Page Deck", content: "A story.", price: 17.99,
                                 duration: "45", description: "The one-line pitch.", category: "Cocktails",
                                 difficulty: "Intermediate")
    sign_in users(:admin)
  end

  def attach_deck_file
    @deck.pdf_file.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "deck.pdf", content_type: "application/pdf")
  end

  def attach_slides(count)
    count.times do |i|
      @deck.slide_images.attach(io: File.open(SLIDE, "rb"), filename: "slide-#{i + 1}.png", content_type: "image/png")
    end
  end

  # --- Routing ---

  test "the old view page redirects to the deck page and keeps the flash" do
    get admin_presentation_path(@deck)
    assert_redirected_to edit_admin_presentation_path(@deck)
  end

  test "a package summary set before a visit to the old view page still shows once" do
    work = Dir.mktmpdir("page-package-show")
    zip = zip_deck_package(build_deck_package(File.join(work, "package")), File.join(work, "p.zip"))
    post admin_presentation_package_path(@deck), params: { package: Rack::Test::UploadedFile.new(zip, "application/zip", true) }
    assert_response :redirect
    # Don't follow it: go to the old view page with the flash still pending.
    get admin_presentation_path(@deck)
    assert_redirected_to edit_admin_presentation_path(@deck)
    follow_redirect!
    assert_select "#package-summary", 1
    get edit_admin_presentation_path(@deck)
    assert_select "#package-summary", 0
  ensure
    FileUtils.remove_entry(work) if work
  end

  test "a package summary survives the redirect and shows once on the deck page" do
    attach_deck_file
    attach_slides(1)
    work = Dir.mktmpdir("page-package")
    zip = zip_deck_package(build_deck_package(File.join(work, "package")), File.join(work, "p.zip"))
    post admin_presentation_package_path(@deck), params: { package: Rack::Test::UploadedFile.new(zip, "application/zip", true) }
    assert_redirected_to edit_admin_presentation_path(@deck)
    follow_redirect!
    assert_select "#package-summary", 1
    get edit_admin_presentation_path(@deck)
    assert_select "#package-summary", 0
  ensure
    FileUtils.remove_entry(work) if work
  end

  test "show passes its flash through to the deck page" do
    # A flash set before a visit to the old URL must not be lost on the way.
    post unpublish_admin_presentation_path(@deck)
    get admin_presentation_path(@deck) # an old bookmark, straight after
    assert_redirected_to edit_admin_presentation_path(@deck)
    follow_redirect!
    assert_response :success
    assert_match(/Unpublished/, response.body)
  end

  test "saving returns to the deck page on the tab the admin was on" do
    patch admin_presentation_path(@deck), params: { tab: "pours", presentation: { title: "Renamed Deck" } }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "pours")
    assert_equal "Renamed Deck", @deck.reload.title
    # Turbo follows the redirect with fetch, which drops the anchor: the tab
    # also comes back in the page's hidden tab field.
    follow_redirect!
    assert_select "input[type=hidden][name=tab][value=pours]"
  end

  test "an unknown tab falls back to the overview" do
    patch admin_presentation_path(@deck), params: { tab: "<script>", presentation: { title: "Renamed Deck" } }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "overview")
  end

  test "a refused save renders the page again with the errors and the tab" do
    patch admin_presentation_path(@deck), params: { tab: "listing", presentation: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Title/
    assert_select "input[type=hidden][name=tab][value=listing]"
    assert_select "#pane-listing .field_with_errors"
    # The fields hold values that were never saved: the leave guard starts on.
    assert_select "form#deck-form[data-unsaved-changes-dirty-value=true]"
  end

  test "a page that loads cleanly starts with the leave guard off" do
    get edit_admin_presentation_path(@deck)
    assert_select "form#deck-form[data-unsaved-changes-dirty-value=false]"
  end

  test "creating a deck lands on its page" do
    post admin_presentations_path, params: { presentation: { title: "Brand New", content: "Story.", price: 5 } }
    assert_redirected_to edit_admin_presentation_path(Presentation.find_by(title: "Brand New"))
  end

  test "publish, unpublish and re-render land back on the deck page" do
    attach_deck_file
    attach_slides(1)
    post publish_admin_presentation_path(@deck)
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "overview")
    post unpublish_admin_presentation_path(@deck)
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "overview")
    post render_slides_admin_presentation_path(@deck), params: { tab: "files" }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "files")
  end

  # --- The header and the tabs ---

  test "the page has the six tabs in order, with counts" do
    attach_slides(2)
    PresentationBottle.create!(presentation: @deck, name: "Woodford Reserve", price: "$40", position: 1)
    get edit_admin_presentation_path(@deck)
    assert_response :success

    tabs = css_select("[data-deck-tabs-target=tab]").map { |t| t.text.squish }
    assert_equal [ "Overview", "Slides and script 2", "Pour list 1", "Listing", "Files 0", "Sales" ], tabs
    %w[overview slides pours listing files sales].each do |pane|
      assert_select "[data-deck-tabs-target=pane][data-pane=#{pane}]", minimum: 1
    end
  end

  test "the header shows the title, the state, the facts and the actions" do
    attach_slides(3)
    PresentationBottle.create!(presentation: @deck, name: "A Pour", position: 1)
    get edit_admin_presentation_path(@deck)

    assert_select "header a[href=?]", admin_presentations_path, text: "← Decks"
    assert_select "header h1", text: "Page Deck"
    assert_select "header", text: /Draft/
    assert_select "header p", text: "$17.99 · 45 min · 3 slides · 1 pour · 0 purchases"
    assert_select "header button[type=submit][form=deck-form]", text: "Save deck"
    assert_select "header a[href=?]", presentation_path(@deck), text: /Preview as buyer/
    assert_select "header", text: /Publish to the library/
    assert_select "title", text: /Page Deck/
  end

  test "the facts line leaves out what the deck does not have" do
    @deck.update_columns(duration: nil)
    get edit_admin_presentation_path(@deck)
    assert_select "header p", text: "$17.99 · 0 purchases"
  end

  test "a published deck shows Published and an Unpublish button in the header" do
    attach_deck_file
    attach_slides(1)
    @deck.update!(published: true)
    get edit_admin_presentation_path(@deck)
    assert_select "header", text: /Published/
    assert_select "header form[action=?]", unpublish_admin_presentation_path(@deck)
  end

  test "the deck form holds every editable field and no other form" do
    attach_deck_file
    attach_slides(1)
    get edit_admin_presentation_path(@deck)
    assert_select "form#deck-form" do
      assert_select "input[name='presentation[title]']"
      assert_select "input[name='presentation[preview_slide_count]']"
      assert_select "input[type=file][name='presentation[pdf_file]']"
      assert_select "input[type=file][name='presentation[speaker_notes]']"
      assert_select "input[type=file][name='presentation[featured_image]']", count: 1
      assert_select "input[type=hidden][name=tab]"
      # The parser drops a nested form's tags but keeps its buttons: the only
      # submit buttons for this form are outside it (form="deck-form").
      assert_select "input[type=submit], button[type=submit], button:not([type])", count: 0
    end
    assert_select "button[type=submit][form=deck-form]", text: "Save deck", count: 2 # header and phone bar
    assert_select "form[action=?]", render_slides_admin_presentation_path(@deck), minimum: 1
  end

  # --- Overview ---

  test "the overview checklist links each item to its tab" do
    attach_slides(4)
    PresentationBottle.create!(presentation: @deck, name: "Unlinked Pour", position: 1)
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-overview" do
      assert_select "a[href='#pane-listing']", text: "The cover"
      assert_select "a[href='#pane-slides']", text: "The slides"
      assert_select "a[href='#pane-pours']", text: "The pour list"
      assert_select "a[href='#pane-files']", text: "What you get"
      assert_select "*", text: /4 rendered · first 3 free/
      assert_select "*", text: /1 pour · none linked to the catalog/
      assert_select "a[href='#pane-pours']", text: /Edit the pour list/
      assert_select "a[href='#pane-files']", text: /Open or replace files/
      assert_select "*", text: /Purchase statistics/
    end
  end

  # --- Slides and script ---

  test "the slides tab shows every slide, the free ones marked, and the preview count field" do
    attach_slides(10)
    @deck.update!(preview_slide_count: 2)
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-slides" do
      assert_select "[data-slide-viewer-target=thumb]", count: 10
      assert_select "[data-slide-viewer-target=badge]:not([hidden])", count: 2
      assert_select "input[name='presentation[preview_slide_count]'][value='2']"
      assert_select "*", text: /Slide 1 of 10/
    end
  end

  test "the slides tab shows the script for each slide, rendered as Markdown and sanitised" do
    attach_slides(2)
    @deck.update_columns(slide_script: [ { "title" => "Opening", "body" => "**Hold up** the cup.\n\n<script>alert(1)</script>" },
                                         { "title" => "Second", "body" => "Pour glass A." } ])
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-slides" do
      assert_select "[data-slide-viewer-target=script]", count: 2
      assert_select "[data-slide-viewer-target=script] strong", text: "Hold up"
      assert_select "[data-slide-viewer-target=script] script", count: 0
      assert_select "input[type=search][placeholder='Find in the script']"
    end
    assert_no_match "<script>alert(1)</script>", response.body
  end

  test "with no script kept, the slides tab offers the speaker notes PDF instead" do
    attach_slides(1)
    @deck.speaker_notes.attach(io: StringIO.new("%PDF-1.4 notes"), filename: "notes.pdf", content_type: "application/pdf")
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-slides" do
      assert_select "[data-slide-viewer-target=script]", count: 0
      assert_select "a[href=?]", admin_presentation_file_path(@deck, "speaker_notes"), text: "Open"
    end
  end

  test "the slides tab keeps the rendering and no-file states" do
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-slides", text: /No deck file/
    attach_deck_file
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-slides", text: /No slide previews yet/
  end

  test "the script is never shown on the buyer page" do
    attach_deck_file
    attach_slides(1)
    @deck.update!(published: true)
    @deck.update_columns(slide_script: [ { "title" => "Secret", "body" => "Only the presenter reads this line." } ])
    get presentation_path(@deck)
    assert_response :success
    assert_no_match "Only the presenter reads this line", response.body
    get present_presentation_path(@deck)
    assert_no_match "Only the presenter reads this line", response.body
  end

  # --- Pour list ---

  test "each pour is a row that opens to its fields" do
    bottle = Bottle.create!(name: "Linked Dram", created_by: users(:admin))
    PresentationBottle.create!(presentation: @deck, name: "Woodford Reserve", origin: "Versailles, Kentucky",
                               price: "$40", position: 1)
    PresentationBottle.create!(presentation: @deck, bottle: bottle, position: 2)
    get edit_admin_presentation_path(@deck)
    rows_selector = "#pane-pours [data-pour-list-target=container] > details.pour-row"
    assert_select rows_selector, count: 2
    assert_select "#{rows_selector}:not([open])", count: 2
    rows = css_select("#{rows_selector} summary").map { |s| s.text.squish }
    assert_match(/\A1 Woodford Reserve Versailles, Kentucky \$40 Not linked/, rows.first)
    assert_match(/\A2 Linked Dram .*Linked/, rows.second)
    assert_select "#pane-pours template details.pour-row[open]", count: 1
    assert_select "#pane-pours button", text: /Add a pour/
  end

  test "a pour with an error opens expanded" do
    bottle = Bottle.create!(name: "Twice Dram", created_by: users(:admin))
    PresentationBottle.create!(presentation: @deck, bottle: bottle, position: 1)
    patch admin_presentation_path(@deck), params: { tab: "pours", presentation: {
      presentation_bottles_attributes: { "0" => { bottle_id: bottle.id, position: 2 } }
    } }
    assert_response :unprocessable_entity
    assert_select "#pane-pours [data-pour-list-target=container] > details.pour-row[open]", minimum: 1
  end

  # --- Files and sales ---

  test "the files tab has a row for every slot, with Open links for what is attached" do
    attach_deck_file
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-files" do
      [ "Deck file", "Speaker notes", "Outline", "Custom tasting scorecard", "Anything else", "Banner image" ].each do |label|
        assert_select ".file-row", text: /#{label}/
      end
      assert_select ".file-row", text: /Sneak peek/, count: 0
      assert_select "a[href=?]", admin_presentation_file_path(@deck, "pdf_file"), text: "Open"
    end
    assert_select "a[href=?]", new_admin_presentation_package_path(@deck), text: "Replace with a package"
  end

  test "the sales tab has the purchases and the analytics link" do
    UserPresentation.create!(user: users(:john), presentation: @deck, purchase_type: "direct",
                             purchase_price: 17.99, purchased_at: Time.current)
    get edit_admin_presentation_path(@deck)
    assert_select "#pane-sales" do
      assert_select "*", text: /Recent purchases/
      assert_select "a[href=?]", admin_presentation_downloads_analytics_path(@deck), text: "Download analytics"
    end
  end

  test "the admin uses Decks, never Presentations, and never calls the pour list Whiskey recommendations" do
    get admin_presentations_path
    assert_select "h1", text: "Decks"
    get edit_admin_presentation_path(@deck)
    assert_no_match "Whiskey recommendations", response.body
    get new_admin_presentation_path
    assert_select "h1", text: "New deck"
    assert_select "a[href=?]", admin_presentations_path, text: "← Decks"
  end

  test "the new-deck form still works in one column" do
    get new_admin_presentation_path
    assert_response :success
    assert_select "form#deck-form input[name='presentation[title]']"
    assert_select "form#deck-form input[type=submit][value='Create draft']"
  end

  # --- One form, every field, saved together ---

  PERMITTED = %w[title description content category tag_names price duration difficulty nose_notes palate_notes
                 finish_notes body_notes what_youll_learn featured_image pdf_file preview_slide_count speaker_notes
                 outline_file scorecard featured free_confirmed supplemental_materials presentation_bottles_attributes].freeze
  # Permitted but never on this form: legacy columns and a legacy upload slot.
  NOT_ON_THE_FORM = %w[tasting_notes image recommendations_sheet].freeze

  test "the deck form carries every permitted field once, from whichever tab it sits on" do
    PresentationBottle.create!(presentation: @deck, name: "A Pour", position: 1)
    get edit_admin_presentation_path(@deck)

    form = css_select("form#deck-form").sole
    fields = form.css("[name]").reject { |node| node["disabled"] || node.ancestors("template").any? }
    names = fields.map { |node| node["name"] }
    keys = names.filter_map { |name| name[/\Apresentation\[([a-z_]+)\]/, 1] }.uniq

    assert_equal [], PERMITTED - keys, "every permitted field is on the form"
    assert_equal [], keys - PERMITTED - NOT_ON_THE_FORM, "nothing on the form that the controller drops"
    assert_equal [], NOT_ON_THE_FORM & keys

    repeats = names.tally.select { |_, count| count > 1 }.keys.reject do |name|
      next true if name.end_with?("[]")
      same = fields.select { |node| node["name"] == name }
      # A check box and its hidden "0" partner.
      same.size == 2 && same.map { |node| node["type"] }.sort == %w[checkbox hidden]
    end
    assert_equal [], repeats, "no field appears twice"
  end

  test "one save stores fields from every tab" do
    attach_slides(4)
    patch admin_presentation_path(@deck), params: { tab: "files", presentation: {
      title: "Saved Everywhere", description: "A new pitch.", content: "## One\n\nThe new story.",
      category: "Bourbon", tag_names: "smoky, islay", price: "21.50", duration: "60", difficulty: "Advanced",
      nose_notes: "Pear", palate_notes: "Oak", finish_notes: "Long", body_notes: "Light",
      what_youll_learn: "- A point\nIts detail", preview_slide_count: "2", featured: "1",
      speaker_notes: fixture_file_upload("sample_scorecard.pdf", "application/pdf"),
      scorecard: fixture_file_upload("sample_scorecard.pdf", "application/pdf"),
      supplemental_materials: [ "", fixture_file_upload("sample_scorecard.pdf", "application/pdf") ],
      presentation_bottles_attributes: { "0" => { name: "Woodford Reserve", origin: "Kentucky", price: "$40", position: 1 } }
    } }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "files")

    @deck.reload
    assert_equal "Saved Everywhere", @deck.title
    assert_equal "A new pitch.", @deck.description
    assert_match "The new story.", @deck.content
    assert_equal "Bourbon", @deck.category
    assert_equal %w[islay smoky], @deck.tags.map(&:name).sort
    assert_equal BigDecimal("21.5"), @deck.price
    assert_equal "60", @deck.duration
    assert_equal "Advanced", @deck.difficulty
    assert_equal %w[Pear Oak Long Light], [ @deck.nose_notes, @deck.palate_notes, @deck.finish_notes, @deck.body_notes ]
    assert_equal 1, @deck.parsed_what_youll_learn.size
    assert_equal 2, @deck.preview_slide_count
    assert @deck.featured?
    assert @deck.speaker_notes.attached?
    assert @deck.scorecard.attached?
    assert_equal 1, @deck.supplemental_materials.count
    assert_equal [ "Woodford Reserve" ], @deck.pour_list.map(&:title)
  end

  # --- "Anything else": saving never loses an extra, and Add files adds ---

  def attach_extra(name = "mat.pdf")
    @deck.supplemental_materials.attach(io: StringIO.new("%PDF-1.4 #{name}"), filename: name, content_type: "application/pdf")
  end

  test "saving any tab keeps the extras when no file was chosen" do
    attach_extra
    patch admin_presentation_path(@deck), params: { presentation: { title: "x Deck", supplemental_materials: [ "" ] } }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "overview")
    assert_equal 1, @deck.reload.supplemental_materials.count
    assert_equal "x Deck", @deck.title
  end

  test "the extras field sends nothing when no file is chosen" do
    get edit_admin_presentation_path(@deck)
    assert_select "input[type=file][name='presentation[supplemental_materials][]']", 1
    assert_select "input[type=hidden][name='presentation[supplemental_materials][]']", 0
  end

  test "Add files adds a new extra beside the ones already there" do
    attach_extra("first.pdf")
    patch admin_presentation_path(@deck), params: { presentation: {
      supplemental_materials: [ "", fixture_file_upload("sample_scorecard.pdf", "application/pdf") ]
    } }
    assert_equal %w[first.pdf sample_scorecard.pdf],
                 @deck.reload.supplemental_materials.attachments.order(:id).map { |a| a.filename.to_s }
  end

  test "a refused save does not lose the extras either" do
    attach_extra
    patch admin_presentation_path(@deck), params: { presentation: {
      title: "", supplemental_materials: [ "", fixture_file_upload("sample_scorecard.pdf", "application/pdf") ]
    } }
    assert_response :unprocessable_entity
    assert_equal 1, @deck.reload.supplemental_materials.count
  end

  # --- File fields take uploads only, never a blob id typed into the request ---

  def stored_blob
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4 someone else's"), filename: "other.pdf",
                                           content_type: "application/pdf")
  end

  test "a signed blob id sent as an extra is not attached" do
    blob = stored_blob
    patch admin_presentation_path(@deck), params: { presentation: { title: "Page Deck", supplemental_materials: [ blob.signed_id ] } }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "overview")
    assert_equal 0, @deck.reload.supplemental_materials.count
  end

  test "a signed blob id sent for a one-file slot is not attached" do
    blob = stored_blob
    patch admin_presentation_path(@deck), params: { presentation: { title: "Still Saves", pdf_file: blob.signed_id,
                                                                     speaker_notes: blob.signed_id } }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "overview")
    @deck.reload
    assert_equal "Still Saves", @deck.title
    assert_not @deck.pdf_file.attached?
    assert_not @deck.speaker_notes.attached?
  end

  test "a garbage string in a file field is ignored, not a 500" do
    patch admin_presentation_path(@deck), params: { presentation: { title: "Page Deck", supplemental_materials: [ "not-a-signed-id" ],
                                                                     scorecard: "not-a-signed-id" } }
    assert_redirected_to edit_admin_presentation_path(@deck, anchor: "overview")
    assert_equal 0, @deck.reload.supplemental_materials.count
    assert_not @deck.scorecard.attached?
  end

  test "creating a deck filters its file fields too, and keeps real uploads" do
    blob = stored_blob
    post admin_presentations_path, params: { presentation: {
      title: "Made With Extras", content: "Story.", price: 5,
      supplemental_materials: [ "", blob.signed_id, fixture_file_upload("sample_scorecard.pdf", "application/pdf") ],
      outline_file: blob.signed_id
    } }
    deck = Presentation.find_by!(title: "Made With Extras")
    assert_redirected_to edit_admin_presentation_path(deck)
    assert_equal [ "sample_scorecard.pdf" ], deck.supplemental_materials.map { |a| a.filename.to_s }
    assert_not deck.outline_file.attached?
  end

  test "a refused create shows no file as uploaded and leaves every file field open" do
    post admin_presentations_path, params: { presentation: {
      title: "", content: "Story.", price: 5,
      scorecard: fixture_file_upload("sample_scorecard.pdf", "application/pdf"),
      supplemental_materials: [ fixture_file_upload("sample_scorecard.pdf", "application/pdf") ]
    } }
    assert_response :unprocessable_entity
    assert_no_match "sample_scorecard.pdf", response.body
    assert_select ".file-row [data-reveal-open-value=true], .file-row[data-reveal-open-value=true]", minimum: 6
    assert_select ".file-row[data-reveal-open-value=false]", 0
    assert_select ".file-row button", text: /Replace|Add files/, count: 0
  end
end
