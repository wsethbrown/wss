require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user favorites a public society" do
    sign_in users(:jane)
    assert_difference "Favorite.count", 1 do
      post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:whiskey_lovers).id }
    end
    assert_redirected_to society_path(societies(:whiskey_lovers))
  end

  test "cannot favorite a private society you can't see" do
    sign_in users(:john)
    assert_no_difference "Favorite.count" do
      post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:bourbon_club).id }
    end
  end

  test "unfavorite destroys the record" do
    sign_in users(:jane)
    assert_difference "Favorite.count", -1 do
      delete favorite_path(favorites(:jane_favorites_single_malt))
    end
  end

  test "cannot destroy someone else's favorite" do
    sign_in users(:john)
    assert_no_difference "Favorite.count" do
      delete favorite_path(favorites(:jane_favorites_single_malt))
    end
    assert_response :not_found
  end

  test "signed-out request redirects to sign in" do
    post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:whiskey_lovers).id }
    assert_redirected_to new_user_session_path
  end

  test "favoriting twice is idempotent, not an error" do
    sign_in users(:jane)
    assert_difference "Favorite.count", 1 do
      post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:whiskey_lovers).id }
    end
    first_redirect = response

    assert_no_difference "Favorite.count" do
      post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:whiskey_lovers).id }
    end
    assert_nil flash[:alert], "second favorite should not show an alert"
    assert_equal "Favorited.", flash[:notice]
  end

  test "unknown favoritable_type 404s" do
    sign_in users(:jane)
    assert_no_difference "Favorite.count" do
      post favorites_path, params: { favoritable_type: "Bottle", favoritable_id: societies(:whiskey_lovers).id }
    end
    assert_response :not_found
  end

  test "a blocked favorite surfaces an alert" do
    sign_in users(:seth)
    assert_no_difference "Favorite.count" do
      post favorites_path, params: { favoritable_type: "Society", favoritable_id: societies(:bourbon_club).id }
    end
    assert flash[:alert], "blocked favorite should show an alert"
    assert flash[:alert].include?("isn't visible to you")
  end
end
