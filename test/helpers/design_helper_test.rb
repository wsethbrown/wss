require "test_helper"

class DesignHelperTest < ActionView::TestCase
  include DesignHelper

  def deck
    @deck ||= Presentation.create!(author: users(:admin), title: "Rye Basics", content: "A story.", price: 5)
  end

  def png
    { io: StringIO.new(Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")),
      filename: "x.png", content_type: "image/png" }
  end

  test "deck_cover falls back to a plain green block" do
    html = deck_cover(deck)
    assert_includes html, "bg-char"
    assert_includes html, "aspect-video"
    assert_not_includes html, "<img"
    assert_not_includes html, deck.title
  end

  test "deck_cover uses the featured image when there are no slides" do
    deck.featured_image.attach(png)
    assert_includes deck_cover(deck), "<img"
  end

  test "deck_cover prefers the first slide by id over the featured image" do
    deck.featured_image.attach(png)
    deck.slide_images.attach([ png.merge(filename: "s1.png"), png.merge(filename: "s2.png") ])
    first = deck.slide_images_attachments.order(:id).first
    assert_equal first, deck_cover_attachment(deck)
    assert_includes deck_cover(deck), "<img"
  end

  test "deck_cover accepts a preloaded attachment" do
    deck.featured_image.attach(png)
    assert_includes deck_cover(deck, preloaded: deck.featured_image), "<img"
  end

  test "avatar shows initials without a profile image" do
    html = avatar(users(:admin), size: 40)
    assert_includes html, "AU"
    assert_includes html, "bg-whiskey-100"
    assert_includes html, "width: 40px"
  end

  test "avatar shows the profile image when attached" do
    user = users(:john)
    user.profile_image.attach(png)
    html = avatar(user)
    assert_includes html, "<img"
    assert_not_includes html, ">JD<"
  end
end
