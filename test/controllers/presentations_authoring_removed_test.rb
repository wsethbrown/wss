require "test_helper"

# Deck authoring lives only in the admin panel. The public presentations
# resource is read-only: index, show and the present player.
class PresentationsAuthoringRemovedTest < ActionDispatch::IntegrationTest
  test "the public authoring routes are not routable" do
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/presentations", method: :post) }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/presentations/1/edit", method: :get) }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/presentations/1", method: :patch) }
    assert_raises(ActionController::RoutingError) { Rails.application.routes.recognize_path("/presentations/1", method: :delete) }
  end

  test "GET /presentations/new is just a show lookup that 404s" do
    get "/presentations/new"
    assert_response :not_found
  end

  test "index, show and present remain routable" do
    assert_equal "index", Rails.application.routes.recognize_path("/presentations")[:action]
    assert_equal "show", Rails.application.routes.recognize_path("/presentations/1")[:action]
    assert_equal "present", Rails.application.routes.recognize_path("/presentations/1/present")[:action]
  end

  test "signed-out POST /presentations does not 500" do
    post "/presentations", params: { presentation: { title: "x" } }
    assert_includes [ 404, 405 ], response.status
  end
end
