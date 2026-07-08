require "test_helper"

class BottlesControllerTest < ActionDispatch::IntegrationTest
  test "creating a bottle with a label image attaches it" do
    sign_in users(:john)
    post bottles_path, params: { bottle: { name: "Redbreast 12", label_image: fixture_file_upload("sample_review.jpg", "image/jpeg") } }
    assert Bottle.find_by!(name: "Redbreast 12").label_image.attached?
  end
end
