require "test_helper"

# I21: the "temporary fix" reset the shared column cache on every admin deck request.
class AdminPresentationsSchemaCacheTest < ActionDispatch::IntegrationTest
  test "viewing the new-deck form does not reset the schema cache" do
    sign_in users(:admin)
    Presentation.expects(:reset_column_information).never
    get new_admin_presentation_path
    assert_response :success
  end
end
