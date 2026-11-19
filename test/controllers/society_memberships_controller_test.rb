require "test_helper"

# B1 (S8): officers manage members, but a society's admins are managed by its
# founder only. The founder remains untouchable.
class SocietyMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @creator = users(:john)
    @society = Society.create!(name: "Roles Club", description: "x", creator: @creator, is_private: false)
    @admin = users(:jane)
    @officer = users(:seth)
    @member = users(:one)
    @admin_m = SocietyMembership.create!(user: @admin, society: @society, role: "admin", status: "active")
    @officer_m = SocietyMembership.create!(user: @officer, society: @society, role: "officer", status: "active")
    @member_m = SocietyMembership.create!(user: @member, society: @society, role: "member", status: "active")
  end

  test "an officer cannot demote a society admin" do
    sign_in @officer
    patch society_membership_path(@admin_m), params: { role: "member" }
    assert_equal "admin", @admin_m.reload.role
  end

  test "an officer cannot remove a society admin" do
    sign_in @officer
    assert_no_difference -> { SocietyMembership.count } do
      delete society_membership_path(@admin_m)
    end
  end

  test "the creator can demote a society admin" do
    sign_in @creator
    patch society_membership_path(@admin_m), params: { role: "member" }
    assert_equal "member", @admin_m.reload.role
  end

  test "the creator can remove a society admin" do
    sign_in @creator
    assert_difference -> { SocietyMembership.count }, -1 do
      delete society_membership_path(@admin_m)
    end
  end

  test "an officer can still manage ordinary members" do
    sign_in @officer
    patch society_membership_path(@member_m), params: { role: "officer" }
    assert_equal "officer", @member_m.reload.role
    assert_difference -> { SocietyMembership.count }, -1 do
      delete society_membership_path(@member_m)
    end
  end

  test "the founder still cannot be removed" do
    sign_in @admin
    founder_m = @society.society_memberships.find_by(user: @creator)
    assert_no_difference -> { SocietyMembership.count } do
      delete society_membership_path(founder_m)
    end
  end

  test "a plain member cannot manage anyone" do
    sign_in @member
    patch society_membership_path(@officer_m), params: { role: "member" }
    assert_equal "officer", @officer_m.reload.role
  end
end
