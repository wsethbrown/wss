require "test_helper"

class SocietyCreationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:john)
    @jane = users(:jane)
    # Creating a society now requires an active membership.
    [ @user, @jane ].each { |u| u.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now) }
  end

  test "complete society creation flow for authenticated user" do
    # Sign in user
    sign_in @user

    # Visit new society page
    get new_society_path
    assert_response :success
    assert_select "h1", /Whiskey Community/
    assert_select "form[action='#{societies_path}']"

    # Fill and submit form
    assert_difference("Society.count", 1) do
      post societies_path, params: {
        society: {
          name: "Integration Test Society",
          description: "A society created through integration testing",
          location: "Test Location",
          is_private: false
        }
      }
    end

    # Check redirect and flash message
    society = Society.last
    assert_redirected_to society_path(society)
    follow_redirect!
    assert_select ".flash-notice", "Society was successfully created."

    # Verify society was created correctly
    assert_equal "Integration Test Society", society.name
    assert_equal "A society created through integration testing", society.description
    assert_equal "Test Location", society.location
    assert_equal false, society.is_private
    assert_equal @user, society.creator

    # Verify creator was added as admin
    membership = society.society_memberships.find_by(user: @user)
    assert_not_nil membership
    assert_equal "admin", membership.role
    assert_equal "active", membership.status
  end

  test "private society creation flow" do
    sign_in @user

    # Create private society
    assert_difference("Society.count", 1) do
      post societies_path, params: {
        society: {
          name: "Private Test Society",
          description: "A private society for testing",
          location: "Secret Location",
          is_private: true
        }
      }
    end

    society = Society.last
    assert society.is_private
    assert_redirected_to society_path(society)

    # Verify private society is not visible to other users
    get society_path(society)
    assert_response :success # creator can see it

    # Sign out and try to access as different user
    delete destroy_user_session_path
    sign_in @jane

    get society_path(society)
    assert_response :redirect
    assert_redirected_to societies_path
    follow_redirect!
    assert_select ".flash-alert", "You are not authorized to view this society."
  end

  test "society creation with validation errors" do
    sign_in @user

    # Submit form with invalid data
    assert_no_difference("Society.count") do
      post societies_path, params: {
        society: {
          name: "", # Invalid - blank
          description: "A description",
          location: "A location",
          is_private: false
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".error-message", /Name can't be blank/
    assert_select "input[name='society[name]']" # Form should be re-rendered
  end

  test "unauthenticated user cannot create society" do
    # Try to visit new society page without authentication
    get new_society_path
    assert_response :redirect
    assert_redirected_to new_user_session_path

    # Try to create society without authentication
    assert_no_difference("Society.count") do
      post societies_path, params: {
        society: {
          name: "Test Society",
          description: "A test society",
          location: "Test Location",
          is_private: false
        }
      }
    end

    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "society index shows correct societies based on authentication" do
    # Create public and private societies
    public_society = Society.create!(
      name: "Public Society",
      creator: @user,
      is_private: false,
      description: "A public society",
      location: "Public Location"
    )

    private_society = Society.create!(
      name: "Private Society",
      creator: @user,
      is_private: true,
      description: "A private society",
      location: "Private Location"
    )

    # Unauthenticated user should only see public societies
    get societies_path
    assert_response :success
    assert_select "h3", text: public_society.name
    assert_select "h3", text: private_society.name, count: 0

    # Authenticated non-member should only see public societies
    sign_in @jane
    get societies_path
    assert_response :success
    assert_select "h3", text: public_society.name
    assert_select "h3", text: private_society.name, count: 0

    # Society creator should see both
    delete destroy_user_session_path
    sign_in @user
    get societies_path
    assert_response :success
    assert_select "h3", text: public_society.name
    assert_select "h3", text: private_society.name

    # Add jane as member of private society
    private_society.society_memberships.create!(user: @jane, role: :member, status: :active)

    # Now jane should see both societies
    delete destroy_user_session_path
    sign_in @jane
    get societies_path
    assert_response :success
    assert_select "h3", text: public_society.name
    assert_select "h3", text: private_society.name
  end

  test "society editing permissions" do
    # Create society as user
    sign_in @user
    society = Society.create!(
      name: "Test Society",
      creator: @user,
      is_private: false,
      description: "A test society",
      location: "Test Location"
    )

    # Creator should be able to edit
    get edit_society_path(society)
    assert_response :success
    assert_select "h1", text: /./ # the reskinned edit page titles itself with the society name
    assert_match "Edit society", response.body

    # Update society: description is the short blurb, about the long story.
    patch society_path(society), params: {
      society: {
        name: "Updated Society Name",
        description: "Updated description",
        about: "The long-form story of this society, told at length."
      }
    }
    assert_redirected_to society_path(society)
    follow_redirect!
    assert_select ".flash-notice", "Society was successfully updated."

    society.reload
    assert_equal "Updated Society Name", society.name
    assert_equal "Updated description", society.description
    assert_equal "The long-form story of this society, told at length.", society.about
    # The About section renders the long story; the masthead keeps the blurb.
    assert_match "The long-form story of this society", response.body

    # Different user should not be able to edit
    delete destroy_user_session_path
    sign_in @jane

    get edit_society_path(society)
    assert_response :redirect
    assert_redirected_to societies_path
    follow_redirect!
    assert_select ".flash-alert", "You are not authorized to edit this society."

    # Attempt to update should also fail
    patch society_path(society), params: {
      society: {
        name: "Hacked Name"
      }
    }

    assert_response :redirect
    assert_redirected_to societies_path
    follow_redirect!
    assert_select ".flash-alert", "You are not authorized to edit this society."

    # Verify society was not updated
    society.reload
    assert_equal "Updated Society Name", society.name
  end

  test "society deletion permissions" do
    # Create society as user
    sign_in @user
    society = Society.create!(
      name: "Test Society",
      creator: @user,
      is_private: false,
      description: "A test society",
      location: "Test Location"
    )

    # Creator should be able to delete
    assert_difference("Society.count", -1) do
      delete society_path(society)
    end

    assert_redirected_to societies_path
    follow_redirect!
    assert_select ".flash-notice", "Society was successfully deleted."

    # Create another society for testing non-creator access
    society2 = Society.create!(
      name: "Another Test Society",
      creator: @user,
      is_private: false,
      description: "Another test society",
      location: "Another Test Location"
    )

    # Different user should not be able to delete
    delete destroy_user_session_path
    sign_in @jane

    assert_no_difference("Society.count") do
      delete society_path(society2)
    end

    assert_response :redirect
    assert_redirected_to societies_path
    follow_redirect!
    assert_select ".flash-alert", "You are not authorized to delete this society."
  end

  test "society membership roles and permissions" do
    # Create society
    sign_in @user
    society = Society.create!(
      name: "Test Society",
      creator: @user,
      is_private: false,
      description: "A test society",
      location: "Test Location"
    )

    # Add jane as officer
    society.society_memberships.create!(user: @jane, role: :officer, status: :active)

    # Officer should be able to edit society
    delete destroy_user_session_path
    sign_in @jane

    get edit_society_path(society)
    assert_response :success

    # Officer should be able to update society
    patch society_path(society), params: {
      society: {
        description: "Updated by officer"
      }
    }

    assert_redirected_to society_path(society)
    follow_redirect!
    assert_select ".flash-notice", "Society was successfully updated."

    society.reload
    assert_equal "Updated by officer", society.description

    # But officer should not be able to delete society
    assert_no_difference("Society.count") do
      delete society_path(society)
    end

    assert_response :redirect
    assert_redirected_to societies_path
    follow_redirect!
    assert_select ".flash-alert", "You are not authorized to delete this society."

    # Change to regular member
    society.society_memberships.find_by(user: @jane).update!(role: :member)

    # Member should not be able to edit
    get edit_society_path(society)
    assert_response :redirect
    assert_redirected_to societies_path
    follow_redirect!
    assert_select ".flash-alert", "You are not authorized to edit this society."
  end
end
