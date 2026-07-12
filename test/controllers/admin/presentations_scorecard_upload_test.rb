require "test_helper"

class Admin::PresentationsScorecardUploadTest < ActionDispatch::IntegrationTest
  test "the edit form renders the custom-scorecard upload field" do
    deck = Presentation.create!(author: users(:admin), title: "Islay Journey", content: "Smoky.", price: 10)
    sign_in users(:admin)

    get edit_admin_presentation_path(deck)
    assert_response :success
    assert_select "input[type=file][name=?]", "presentation[scorecard]"
    assert_select "label", text: /Custom tasting scorecard/
  end

  test "admin can upload a custom scorecard on the deck edit form" do
    deck = Presentation.create!(author: users(:admin), title: "Islay Journey", content: "Smoky.", price: 10)
    sign_in users(:admin)

    patch admin_presentation_path(deck), params: {
      presentation: { scorecard: fixture_file_upload("sample_scorecard.pdf", "application/pdf") }
    }

    assert_response :redirect
    assert deck.reload.scorecard.attached?, "expected the uploaded scorecard to persist"
  end
end
