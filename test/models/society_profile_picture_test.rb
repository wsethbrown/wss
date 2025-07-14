require 'test_helper'

class SocietyProfilePictureTest < ActiveSupport::TestCase
  test "should handle HEIC profile pictures" do
    society = Society.find(2)
    
    # Check if profile picture is attached
    assert society.profile_picture.attached?, "Profile picture should be attached"
    
    # Check content type
    content_type = society.profile_picture.blob.content_type
    puts "Content type: #{content_type}"
    
    # Check if it's HEIC
    is_heic = content_type == "image/heic" || content_type == "image/heif"
    puts "Is HEIC: #{is_heic}"
    
    if is_heic
      # Try to create a variant
      variant = society.profile_picture.variant(resize_to_fill: [160, 160], format: :jpeg)
      puts "Variant key: #{variant.key}"
      
      # Try to process the variant
      variant.processed
      puts "Variant processed successfully"
    end
  end
end