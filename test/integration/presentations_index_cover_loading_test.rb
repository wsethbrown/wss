require "test_helper"

# The first row of the deck index (3 columns at desktop) is above the fold, so
# its covers load eagerly; a lazy cover can sit as an empty dark box for a
# moment. Later covers stay lazy.
class PresentationsIndexCoverLoadingTest < ActionDispatch::IntegrationTest
  PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==".freeze

  def published_deck_with_cover(title)
    deck = Presentation.create!(author: users(:admin), title: title, content: "A story.", price: 5)
    deck.featured_image.attach(io: StringIO.new(Base64.decode64(PNG)), filename: "x.png", content_type: "image/png")
    deck.update_column(:published, true)
    deck
  end

  test "the first row of covers is eager and the rest are lazy" do
    5.times { |i| published_deck_with_cover("Cover Deck #{i}") }

    get presentations_path
    assert_response :success

    loadings = css_select("img[data-appear-target='image']").map { |img| img["loading"] }
    assert_operator loadings.size, :>=, 5
    assert_equal %w[eager eager eager], loadings.first(3)
    assert loadings.drop(3).all? { |l| l == "lazy" }, "covers after the first row must stay lazy, got #{loadings.inspect}"
  end
end
