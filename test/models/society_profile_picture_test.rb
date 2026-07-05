require "test_helper"

class SocietyProfilePictureTest < ActiveSupport::TestCase
  # Was an exploratory script (Society.find(2) + puts) that depended on a HEIC
  # image existing in the dev database. Rewritten as a self-contained test of
  # the profile-picture attachment itself. Variant/format conversion is not
  # exercised here because it needs libvips/libheif, which the CI image omits.
  test "society can attach and expose a profile picture" do
    society = societies(:whiskey_lovers)

    society.profile_picture.attach(
      io: File.open(Rails.root.join("app/assets/images/wss-logo.jpg")),
      filename: "wss-logo.jpg",
      content_type: "image/jpeg"
    )

    assert society.profile_picture.attached?, "Profile picture should be attached"
    assert_equal "image/jpeg", society.profile_picture.blob.content_type
  end
end
