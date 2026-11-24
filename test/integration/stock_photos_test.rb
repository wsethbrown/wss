require "test_helper"

# Three interim stock photographs (owner-approved, to be replaced later), one
# per view, each printed through shared/_duotone in the heavy two-ink variant
# so no face is recognisable, sized so the browser reserves their space, never
# behind text, and credited in docs/redesign/IMAGE_CREDITS.md.
class StockPhotosTest < ActionDispatch::IntegrationTest
  CREDITS = Rails.root.join("docs/redesign/IMAGE_CREDITS.md")

  def assert_one_heavy_photo(file, width, height)
    assert_select "figure.duotone", 1, "one photograph per view"
    assert_select "figure.duotone.duotone--heavy img", 1 do |imgs|
      img = imgs.first
      assert_match %r{photos/#{Regexp.escape(file)}.*\.jpg}, img["src"]
      assert_equal width.to_s, img["width"]
      assert_equal height.to_s, img["height"]
      assert img["alt"].present?, "a plain description of the photo"
      refute_includes img["alt"], "—", "no em-dashes"
      assert_equal "lazy", img["loading"]
    end
    # Never behind text: the figure holds only its image.
    assert_equal "", css_select("figure.duotone").text.strip
  end

  test "the sign-in page has a tall photo beside the form on wide screens only" do
    get auth_path
    assert_response :success
    assert_one_heavy_photo("signin-sofa-lamp", 640, 800)
    classes = css_select("figure.duotone").first["class"].split
    assert_includes classes, "hidden"
    assert_includes classes, "lg:block"
    assert_includes classes, "aspect-[4/5]"
  end

  test "the signed-in reviews rail opens with a small photo above the circle card" do
    sign_in users(:john)
    get reviews_path
    assert_response :success
    assert_one_heavy_photo("reviews-glass-book", 1280, 960)
    assert_includes css_select("figure.duotone").first["class"], "aspect-[4/3]"
  end

  test "signed out, the reviews page has no rail and no photo" do
    get reviews_path
    assert_select "figure.duotone", 0
  end

  test "the deck page has a wide band after the story" do
    deck = Presentation.create!(author: users(:admin), title: "Band Deck", content: "A story.", price: 10)
    deck.update_column(:published, true)
    get presentation_path(deck)
    assert_response :success
    assert_one_heavy_photo("deck-pour-decanter", 1280, 427)
    assert_includes css_select("figure.duotone").first["class"], "sm:aspect-[3/1]", "3:1 on wider screens (2:1 on phones, where 3:1 is a sliver)"
  end

  test "the library page has no photograph" do
    get presentations_path
    assert_select "figure.duotone", 0
  end

  test "the heavy duotone prints light in orange and shadows in ink" do
    css = File.read(Rails.root.join("app/assets/tailwind/application.css"))
    assert_match(/\.duotone--heavy\s*\{\s*background:\s*var\(--color-mark\);\s*\}/, css)
    assert_match(/\.duotone--heavy::after\s*\{\s*background:\s*var\(--color-ink\);\s*\}/, css)
  end

  test "each stock photo is credited with its source, photographer and licence" do
    credits = File.read(CREDITS)
    {
      "signin-sofa-lamp.jpg" => [ "pexels.com/photo/people-sitting-in-the-living-room-8556115", "Polina Tankilevitch", "Pexels License" ],
      "reviews-glass-book.jpg" => [ "unsplash.com/photos/a-person-reading-a-book-and-drinking-a-glass-of-whiskey-kJMgr2LT4RQ", "OurWhisky Foundation", "Unsplash License" ],
      "deck-pour-decanter.jpg" => [ "pexels.com/photo/a-person-pouring-brown-liquid-in-the-glass-4457112", "Taryn Elliott", "Pexels License" ]
    }.each do |file, facts|
      line = credits.lines.find { |l| l.include?(file) }
      assert line, "#{file} is credited"
      facts.each { |fact| assert_includes line, fact, file }
      assert_includes line, "2026-11-22"
      assert_match(/Interim stock/i, line)
      assert File.exist?(Rails.root.join("app/assets/images/photos", file))
    end
  end
end
