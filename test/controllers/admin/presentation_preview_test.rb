require "test_helper"

# "What the customer sees": POST the deck form's fields, get back the deck
# page's top, takeaways, story teaser and extra sections rendered by the deck
# page's own partials. Nothing is ever saved.
class Admin::PresentationPreviewTest < ActionDispatch::IntegrationTest
  SLIDE = Rails.root.join("test/fixtures/files/slides/slide-01.png")
  LONG_STORY = (1..40).map { |n| "Story line #{n}." }.join("\n")

  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Saved Title", content: "The saved story, paid in full.",
                                 price: 12, description: "The saved pitch.", category: "Rye")
    sign_in users(:admin)
  end

  def typed(**fields)
    { presentation: { title: "Typed Title", description: "A typed pitch.", category: "Cocktails",
                      difficulty: "Beginner", duration: "45", content: "## Opening\n\nA typed story." }.merge(fields) }
  end

  test "renders what was typed, by the deck page's partials" do
    post preview_admin_presentation_path(@deck), params: typed(
      what_youll_learn: "- A typed takeaway\nIts line.",
      sections: [ { heading: "" }, { heading: "On the night", lines: "Glass A: first\nGlass B: later" },
                  { heading: "Who it's for", lines: "New to rye." } ]
    )
    assert_response :success
    assert_select "h1", text: "Typed Title"
    assert_select "header p", text: "Cocktails · Beginner · 45 min"
    assert_select "header p", text: "A typed pitch."
    assert_select "ol h3", text: "A typed takeaway"
    assert_select "#deck-story h2", text: "A taste of the writing"
    assert_select "#deck-story", text: /A typed story\./
    assert_equal [ "On the night", "Who it's for" ], css_select("[data-deck-section] h2").map(&:text)
    assert_select "[data-deck-section] li span.text-mute", text: "Glass A"
    assert_select "[data-deck-section] p.font-reading", text: "New to rye."
    assert_no_match "Saved Title", response.body
  end

  test "shows the typed subtitle under the title, and nothing when it is blank" do
    post preview_admin_presentation_path(@deck), params: typed(subtitle: "A typed <i>subtitle</i>")
    assert_select "header [data-deck-subtitle]", text: "A typed <i>subtitle</i>"
    assert_no_match "<i>subtitle</i>", response.body
    post preview_admin_presentation_path(@deck), params: typed(subtitle: " ")
    assert_select "[data-deck-subtitle]", 0
  end

  test "never saves, and never touches files or pours" do
    @deck.update!(sections: [ { "heading" => "Saved", "lines" => [ "x" ] } ])
    before = @deck.reload.attributes
    assert_no_difference [ -> { Presentation.count }, -> { Tag.count }, -> { PresentationTag.count },
                           -> { PresentationBottle.count }, -> { ActiveStorage::Attachment.count },
                           -> { ActiveStorage::Blob.count } ] do
      post preview_admin_presentation_path(@deck), params: typed(
        price: "0", featured: "1", tag_names: "new, tags", subtitle: "Unsaved subtitle",
        sections: [ { heading: "Unsaved", lines: "y" } ],
        pdf_file: fixture_file_upload("sample_scorecard.pdf", "application/pdf"),
        presentation_bottles_attributes: { "0" => { name: "Unsaved Pour", position: 1 } }
      )
    end
    assert_response :success
    assert_equal before, @deck.reload.attributes
    assert_equal [], @deck.tags.to_a
  end

  test "shows the saved cover and slide count, but never the stored story or the slide script" do
    2.times { |i| @deck.slide_images.attach(io: File.open(SLIDE, "rb"), filename: "slide-#{i}.png", content_type: "image/png") }
    @deck.update_columns(content: LONG_STORY, slide_script: [ { "title" => "Secret", "body" => "Only the presenter reads this." } ])

    post preview_admin_presentation_path(@deck), params: typed(content: "")
    assert_response :success
    assert_select "header p", text: /2 slides/
    assert_select "header img[alt=?]", "Typed Title, first slide"
    assert_no_match "Story line", response.body, "the stored story is not read"
    assert_no_match "Only the presenter reads this", response.body
    assert_no_match "paid in full", response.body
  end

  test "shows only the teaser of a long story, never the whole of it" do
    post preview_admin_presentation_path(@deck), params: typed(content: LONG_STORY)
    assert_response :success
    assert_match "Story line 24.", response.body
    assert_no_match "Story line 25.", response.body
    assert_no_match "Story line 40.", response.body
    assert_select "#deck-story", text: /The story keeps going\./
  end

  test "works for a deck not created yet, with no cover" do
    assert_no_difference -> { Presentation.count } do
      post preview_admin_presentations_path, params: typed(sections: [ { heading: "Plain", lines: "One line." } ])
    end
    assert_response :success
    assert_select "h1", text: "Typed Title"
    assert_select "header img", 0
    assert_select "[data-deck-section] h2", text: "Plain"
  end

  test "escapes what was typed" do
    post preview_admin_presentations_path, params: typed(title: "<script>alert(1)</script>",
                                                          sections: [ { heading: "<b>H</b>", lines: "<i>x</i>: y" } ])
    assert_no_match "<script>alert(1)</script>", response.body
    assert_no_match "<b>H</b>", response.body
    assert_select "[data-deck-section] h2", text: "<b>H</b>"
  end

  test "is for admins only" do
    sign_out :user
    post preview_admin_presentation_path(@deck), params: typed
    assert_redirected_to root_path

    sign_in users(:john)
    post preview_admin_presentation_path(@deck), params: typed
    assert_redirected_to root_path
    assert_no_match "Typed Title", response.body
  end

  test "an unknown deck or a request without fields is refused" do
    post "/admin/presentations/0/preview", params: typed
    assert_response :not_found
    post preview_admin_presentation_path(@deck)
    assert_response :bad_request
  end
end
