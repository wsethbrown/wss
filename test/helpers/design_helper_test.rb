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

  # B16: pages show named variants, never the original upload.
  test "deck_cover and avatar point at named variants, not the original blob" do
    deck.featured_image.attach(png)
    assert_match %r{/rails/active_storage/representations/}, deck_cover(deck)
    assert_no_match %r{/rails/active_storage/blobs/}, deck_cover(deck)

    user = users(:john)
    user.profile_image.attach(png)
    assert_match %r{/rails/active_storage/representations/}, avatar(user, size: 40)
  end

  test "named variants exist on every displayed attachment" do
    assert_equal %i[card hero], Presentation.reflect_on_attachment(:featured_image).named_variants.keys.sort
    assert_equal %i[card hero], Presentation.reflect_on_attachment(:slide_images).named_variants.keys.sort
    assert_equal %i[avatar thumb], User.reflect_on_attachment(:profile_image).named_variants.keys.sort
    assert_equal %i[avatar thumb], Society.reflect_on_attachment(:profile_picture).named_variants.keys.sort
    assert_equal %i[hero], Society.reflect_on_attachment(:banner_image).named_variants.keys
    [ [ Presentation, :featured_image ], [ Presentation, :slide_images ], [ User, :profile_image ],
      [ Society, :profile_picture ], [ Society, :banner_image ] ].each do |model, name|
      model.reflect_on_attachment(name).named_variants.each do |variant, definition|
        assert definition.preprocessed?(model.new), "#{model}##{name} :#{variant} should be preprocessed"
      end
    end
  end

  test "named variants really process with libvips" do
    deck.featured_image.attach(png)
    assert deck.featured_image.variant(:card).processed.image.attached?
  end

  test "image_variant serves the original only when the file cannot be transformed, and logs it" do
    deck.supplemental_materials.attach(io: StringIO.new("plain"), filename: "a.txt", content_type: "text/plain")
    attachment = deck.supplemental_materials.first
    Rails.logger.expects(:warn).with(regexp_matches(/not variable/)).once
    assert_equal attachment, image_variant(attachment, :card)
  end
end
