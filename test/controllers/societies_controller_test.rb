require "test_helper"

class SocietiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @society = societies(:whiskey_lovers)
    @admin_user = users(:admin)
    # Creating/managing a society now requires an active membership.
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
  end

  # Index action tests
  test "should get index when not authenticated" do
    get societies_url
    assert_response :success
    # Unauthenticated visitors get the marketing landing; its hero headline ends
    # with "Find Your Society." and it features public societies below.
    assert_select "h1", /Find Your Society/
  end

  test "should get index when authenticated" do
    sign_in @user
    get societies_url
    assert_response :success
  end

  test "should show only public societies to unauthenticated users" do
    get societies_url
    assert_select ".society-card", count: 2 # whiskey_lovers and single_malt are public
  end

  # Show action tests
  test "should show public society to anyone" do
    get society_url(@society)
    assert_response :success
    assert_select "h1", @society.name
  end

  test "should show private society to members" do
    private_society = societies(:bourbon_club)
    sign_in users(:jane) # creator of bourbon_club
    get society_url(private_society)
    assert_response :success
  end

  test "should redirect private society to unauthorized users" do
    private_society = societies(:bourbon_club)
    get society_url(private_society)
    assert_response :redirect
    assert_redirected_to societies_url
    assert_equal "You are not authorized to view this society.", flash[:alert]
  end

  # New action tests
  test "should get new when authenticated" do
    sign_in @user
    get new_society_url
    assert_response :success
    assert_select "h1", /Whiskey Community/
  end

  test "should redirect to sign in when not authenticated" do
    get new_society_url
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  # Create action tests
  test "a signed-in non-member cannot create a society" do
    non_member = users(:jane)
    non_member.update!(subscription_status: nil)
    sign_in non_member

    assert_no_difference("Society.count") do
      post societies_url, params: { society: { name: "Freeloaders", description: "For the unsubscribed" } }
    end
    assert_redirected_to societies_path
  end

  test "should create society when authenticated with valid params" do
    sign_in @user

    assert_difference("Society.count") do
      post societies_url, params: {
        society: {
          name: "New Test Society",
          description: "A brand new society for testing",
          location: "Test City",
          is_private: false
        }
      }
    end

    society = Society.last
    assert_redirected_to society_url(society)
    assert_equal "Society was successfully created.", flash[:notice]
    assert_equal @user, society.creator

    # Check that creator is automatically added as admin
    membership = society.society_memberships.find_by(user: @user)
    assert_not_nil membership
    assert_equal "admin", membership.role
    assert_equal "active", membership.status
  end

  test "should not create society when not authenticated" do
    assert_no_difference("Society.count") do
      post societies_url, params: {
        society: {
          name: "New Test Society",
          description: "A brand new society for testing",
          location: "Test City",
          is_private: false
        }
      }
    end

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "should not create society with invalid params" do
    sign_in @user

    assert_no_difference("Society.count") do
      post societies_url, params: {
        society: {
          name: "", # Invalid - blank name
          description: "A description",
          location: "Test City",
          is_private: false
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error-message", /Name can't be blank/
  end

  test "should create private society" do
    sign_in @user

    assert_difference("Society.count") do
      post societies_url, params: {
        society: {
          name: "Private Test Society",
          description: "A private society for testing",
          location: "Test City",
          is_private: true
        }
      }
    end

    society = Society.last
    assert society.is_private
    assert_redirected_to society_url(society)
  end

  test "should handle long description" do
    sign_in @user

    assert_no_difference("Society.count") do
      post societies_url, params: {
        society: {
          name: "Test Society",
          description: "x" * 1001, # Too long
          location: "Test City",
          is_private: false
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error-message", /Description is too long/
  end

  test "should handle long location" do
    sign_in @user

    assert_no_difference("Society.count") do
      post societies_url, params: {
        society: {
          name: "Test Society",
          description: "A description",
          location: "x" * 201, # Too long
          is_private: false
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error-message", /Location is too long/
  end

  # Edit action tests
  test "should get edit when authorized" do
    sign_in @user # creator of @society
    get edit_society_url(@society)
    assert_response :success
    assert_select "h1", text: /./ # the reskinned edit page titles itself with the society name
    assert_match "Edit society", response.body
  end

  test "should not get edit when not authorized" do
    sign_in users(:jane) # not creator
    get edit_society_url(@society)
    assert_response :redirect
    assert_redirected_to societies_url
    assert_equal "You are not authorized to edit this society.", flash[:alert]
  end

  test "should not get edit when not authenticated" do
    get edit_society_url(@society)
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  # Update action tests
  test "should update society when authorized" do
    sign_in @user # creator of @society

    patch society_url(@society), params: {
      society: {
        name: "Updated Society Name",
        description: "Updated description"
      }
    }

    assert_redirected_to society_url(@society)
    assert_equal "Society was successfully updated.", flash[:notice]
    @society.reload
    assert_equal "Updated Society Name", @society.name
    assert_equal "Updated description", @society.description
  end

  test "should not update society when not authorized" do
    sign_in users(:jane) # not creator
    original_name = @society.name

    patch society_url(@society), params: {
      society: {
        name: "Hacked Name"
      }
    }

    assert_response :redirect
    assert_redirected_to societies_url
    assert_equal "You are not authorized to edit this society.", flash[:alert]
    @society.reload
    assert_equal original_name, @society.name
  end

  test "should not update society with invalid params" do
    sign_in @user

    patch society_url(@society), params: {
      society: {
        name: "" # Invalid
      }
    }

    assert_response :unprocessable_entity
    assert_select ".error-message", /Name can't be blank/
  end

  # Destroy action tests
  test "should destroy society when authorized" do
    sign_in @user # creator of @society

    assert_difference("Society.count", -1) do
      delete society_url(@society)
    end

    assert_redirected_to societies_url
    assert_equal "Society was successfully deleted.", flash[:notice]
  end

  test "should not destroy society when not authorized" do
    sign_in users(:jane) # not creator

    assert_no_difference("Society.count") do
      delete society_url(@society)
    end

    assert_response :redirect
    assert_redirected_to societies_url
    assert_equal "You are not authorized to delete this society.", flash[:alert]
  end

  test "should not destroy society when not authenticated" do
    assert_no_difference("Society.count") do
      delete society_url(@society)
    end

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end
end
