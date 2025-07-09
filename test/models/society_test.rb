require "test_helper"

class SocietyTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @society = societies(:whiskey_lovers)
  end

  # Validation tests
  test "should be valid with valid attributes" do
    society = Society.new(
      name: "Test Society",
      description: "A test society",
      location: "Test City",
      creator: @user,
      is_private: false
    )
    assert society.valid?
  end

  test "should require name" do
    society = Society.new(creator: @user, is_private: false)
    assert_not society.valid?
    assert_includes society.errors[:name], "can't be blank"
  end

  test "should require name to be at least 2 characters" do
    society = Society.new(name: "A", creator: @user, is_private: false)
    assert_not society.valid?
    assert_includes society.errors[:name], "is too short (minimum is 2 characters)"
  end

  test "should require name to be at most 100 characters" do
    society = Society.new(name: "x" * 101, creator: @user, is_private: false)
    assert_not society.valid?
    assert_includes society.errors[:name], "is too long (maximum is 100 characters)"
  end

  test "should limit description to 1000 characters" do
    society = Society.new(
      name: "Test",
      description: "x" * 1001,
      creator: @user,
      is_private: false
    )
    assert_not society.valid?
    assert_includes society.errors[:description], "is too long (maximum is 1000 characters)"
  end

  test "should limit location to 200 characters" do
    society = Society.new(
      name: "Test",
      location: "x" * 201,
      creator: @user,
      is_private: false
    )
    assert_not society.valid?
    assert_includes society.errors[:location], "is too long (maximum is 200 characters)"
  end

  test "should require is_private to be boolean" do
    society = Society.new(
      name: "Test",
      creator: @user,
      is_private: nil
    )
    assert_not society.valid?
    assert_includes society.errors[:is_private], "is not included in the list"
  end

  # Association tests
  test "should belong to creator" do
    assert_equal @user, @society.creator
  end

  test "should have many society memberships" do
    assert_respond_to @society, :society_memberships
  end

  test "should have many members through society memberships" do
    assert_respond_to @society, :members
  end

  # Callback tests
  test "should add creator as admin after creation" do
    society = Society.create!(
      name: "New Society",
      creator: @user,
      is_private: false
    )
    
    membership = society.society_memberships.find_by(user: @user)
    assert_not_nil membership
    assert_equal 'admin', membership.role
    assert_equal 'active', membership.status
  end

  # Instance method tests
  test "member_count should return count of active members" do
    # Create some memberships
    user2 = users(:jane)
    @society.society_memberships.create!(user: user2, role: :member, status: :active)
    @society.society_memberships.create!(user: users(:admin), role: :member, status: :inactive)
    
    assert_equal 2, @society.member_count # creator + jane (admin status doesn't count as additional)
  end

  test "has_admin? should return true for admin members" do
    admin_user = users(:admin)
    @society.society_memberships.create!(user: admin_user, role: :admin, status: :active)
    
    assert @society.has_admin?(admin_user)
    assert_not @society.has_admin?(users(:jane))
  end

  test "has_member? should return true for any active member" do
    member_user = users(:jane)
    @society.society_memberships.create!(user: member_user, role: :member, status: :active)
    
    assert @society.has_member?(member_user)
    assert_not @society.has_member?(users(:admin))
  end

  test "can_manage? should return true for admins and officers" do
    admin_user = users(:admin)
    officer_user = users(:jane)
    
    @society.society_memberships.create!(user: admin_user, role: :admin, status: :active)
    @society.society_memberships.create!(user: officer_user, role: :officer, status: :active)
    
    assert @society.can_manage?(admin_user)
    assert @society.can_manage?(officer_user)
  end

  test "public? should return opposite of is_private" do
    public_society = societies(:whiskey_lovers)
    private_society = societies(:bourbon_club)
    
    assert public_society.public?
    assert_not private_society.public?
  end

  test "private? should return value of is_private" do
    public_society = societies(:whiskey_lovers)
    private_society = societies(:bourbon_club)
    
    assert_not public_society.private?
    assert private_society.private?
  end

  # Scope tests
  test "public_societies scope should return only public societies" do
    public_societies = Society.public_societies
    
    assert_includes public_societies, societies(:whiskey_lovers)
    assert_includes public_societies, societies(:single_malt)
    assert_not_includes public_societies, societies(:bourbon_club)
  end

  test "private_societies scope should return only private societies" do
    private_societies = Society.private_societies
    
    assert_includes private_societies, societies(:bourbon_club)
    assert_not_includes private_societies, societies(:whiskey_lovers)
    assert_not_includes private_societies, societies(:single_malt)
  end

  test "search scope should find societies by name or description" do
    results = Society.search("bourbon")
    assert_includes results, societies(:bourbon_club)
    
    results = Society.search("passionate")
    assert_includes results, societies(:whiskey_lovers)
  end

  test "by_location scope should find societies by location" do
    results = Society.by_location("New York")
    assert_includes results, societies(:whiskey_lovers)
    
    results = Society.by_location("Louisville")
    assert_includes results, societies(:bourbon_club)
  end
end