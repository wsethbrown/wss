require "test_helper"

class SocietyPolicyTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @other_user = users(:jane)
    @admin_user = users(:admin)
    @society = societies(:whiskey_lovers) # created by john
    @private_society = societies(:bourbon_club) # created by jane
  end

  # Index policy tests
  test "index? should allow anyone" do
    assert SocietyPolicy.new(nil, Society).index?
    assert SocietyPolicy.new(@user, Society).index?
    assert SocietyPolicy.new(@other_user, Society).index?
  end

  # Show policy tests
  test "show? should allow anyone for public societies" do
    assert SocietyPolicy.new(nil, @society).show?
    assert SocietyPolicy.new(@user, @society).show?
    assert SocietyPolicy.new(@other_user, @society).show?
  end

  test "show? should only allow members for private societies" do
    # Creator should be able to see their private society
    assert SocietyPolicy.new(@other_user, @private_society).show?

    # Non-members should not be able to see private society
    assert_not SocietyPolicy.new(@user, @private_society).show?
    assert_not SocietyPolicy.new(nil, @private_society).show?

    # Add user as member and test access
    @private_society.society_memberships.create!(user: @user, role: :member, status: :active)
    assert SocietyPolicy.new(@user, @private_society).show?
  end

  # Create/new is a membership benefit — signed in is not enough.
  test "new? follows create?: members and admins only" do
    assert_not SocietyPolicy.new(nil, Society).new?
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    assert SocietyPolicy.new(@user, Society).new?           # active member
    assert_not SocietyPolicy.new(@other_user, Society).new? # signed in, no membership
    assert SocietyPolicy.new(@admin_user, Society).new?     # admin
  end

  test "create? requires an active membership (or admin)" do
    assert_not SocietyPolicy.new(nil, Society).create?
    assert_not SocietyPolicy.new(@other_user, Society).create? # signed in, no membership
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    assert SocietyPolicy.new(@user, Society).create?           # active member
    assert SocietyPolicy.new(@admin_user, Society).create?     # admin superuser
  end

  # Edit policy tests
  test "edit? should only allow creators and admins" do
    # Creator should be able to edit
    assert SocietyPolicy.new(@user, @society).edit?

    # Other users should not be able to edit
    assert_not SocietyPolicy.new(@other_user, @society).edit?
    assert_not SocietyPolicy.new(nil, @society).edit?

    # Add user as admin and test access
    @society.society_memberships.create!(user: @other_user, role: :admin, status: :active)
    assert SocietyPolicy.new(@other_user, @society).edit?

    # Officers should also be able to edit
    @society.society_memberships.find_by(user: @other_user).update!(role: :officer)
    assert SocietyPolicy.new(@other_user, @society).edit?

    # Regular members should not be able to edit
    @society.society_memberships.find_by(user: @other_user).update!(role: :member)
    assert_not SocietyPolicy.new(@other_user, @society).edit?
  end

  # Update policy tests
  test "update? should have same rules as edit?" do
    # Creator should be able to update
    assert SocietyPolicy.new(@user, @society).update?

    # Other users should not be able to update
    assert_not SocietyPolicy.new(@other_user, @society).update?
    assert_not SocietyPolicy.new(nil, @society).update?

    # Add user as admin and test access
    @society.society_memberships.create!(user: @other_user, role: :admin, status: :active)
    assert SocietyPolicy.new(@other_user, @society).update?
  end

  # Destroy policy tests
  test "destroy? should only allow creators" do
    # Creator should be able to destroy
    assert SocietyPolicy.new(@user, @society).destroy?

    # Other users should not be able to destroy, even admins
    assert_not SocietyPolicy.new(@other_user, @society).destroy?
    assert_not SocietyPolicy.new(nil, @society).destroy?

    # Even admin members should not be able to destroy
    @society.society_memberships.create!(user: @other_user, role: :admin, status: :active)
    assert_not SocietyPolicy.new(@other_user, @society).destroy?
  end

  # Scope tests
  test "scope should return public societies for unauthenticated users" do
    scope = SocietyPolicy::Scope.new(nil, Society).resolve

    assert_includes scope, societies(:whiskey_lovers)
    assert_includes scope, societies(:single_malt)
    assert_not_includes scope, societies(:bourbon_club)
  end

  test "scope should return accessible societies for authenticated users" do
    # User should see public societies plus private societies they're members of
    scope = SocietyPolicy::Scope.new(@user, Society).resolve

    assert_includes scope, societies(:whiskey_lovers)
    assert_includes scope, societies(:single_malt)
    assert_not_includes scope, societies(:bourbon_club) # not a member

    # Add user as member of private society
    societies(:bourbon_club).society_memberships.create!(user: @user, role: :member, status: :active)

    # Now they should see it
    scope = SocietyPolicy::Scope.new(@user, Society).resolve
    assert_includes scope, societies(:bourbon_club)
  end

  test "scope should return all societies user has access to" do
    # Create additional private society
    private_society = Society.create!(
      name: "Another Private Society",
      creator: @admin_user,
      is_private: true,
      description: "Another private society",
      location: "Somewhere"
    )

    # User should not see the new private society
    scope = SocietyPolicy::Scope.new(@user, Society).resolve
    assert_not_includes scope, private_society

    # Add user as member
    private_society.society_memberships.create!(user: @user, role: :member, status: :active)

    # Now they should see it
    scope = SocietyPolicy::Scope.new(@user, Society).resolve
    assert_includes scope, private_society
  end

  # Test with inactive memberships
  test "scope should not return private societies for inactive members" do
    # Add user as inactive member
    societies(:bourbon_club).society_memberships.create!(user: @user, role: :member, status: :inactive)

    # User should not see the private society
    scope = SocietyPolicy::Scope.new(@user, Society).resolve
    assert_not_includes scope, societies(:bourbon_club)

    # Activate membership
    societies(:bourbon_club).society_memberships.find_by(user: @user).update!(status: :active)

    # Now they should see it
    scope = SocietyPolicy::Scope.new(@user, Society).resolve
    assert_includes scope, societies(:bourbon_club)
  end

  # Test creator permissions
  test "creator should have all permissions on their societies" do
    policy = SocietyPolicy.new(@user, @society)

    assert policy.show?
    assert policy.edit?
    assert policy.update?
    assert policy.destroy?
  end

  test "creator should have permissions on their private societies" do
    policy = SocietyPolicy.new(@other_user, @private_society)

    assert policy.show?
    assert policy.edit?
    assert policy.update?
    assert policy.destroy?
  end

  # Test edge cases
  test "should handle nil user gracefully" do
    policy = SocietyPolicy.new(nil, @society)

    assert policy.show? # public society
    assert_not policy.edit?
    assert_not policy.update?
    assert_not policy.destroy?
    assert_not policy.new?
    assert_not policy.create?
  end

  test "should handle nil society gracefully" do
    @user.update!(subscription_status: "active", subscription_ends_at: 1.month.from_now)
    policy = SocietyPolicy.new(@user, nil)

    assert policy.new?
    assert policy.create?
    assert policy.index?
  end
end
