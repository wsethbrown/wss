require "test_helper"

# B18: the deck catalogue is public to browse. The policy grants no write
# powers (authoring lives in the admin namespace), so any method that could
# be mistaken for one must stay false for everybody, admins included.
class PresentationPolicyTest < ActiveSupport::TestCase
  setup do
    @deck = Presentation.create!(author: users(:admin), title: "Policy Deck", content: "Story.", price: 10)
  end

  test "anyone, signed out or in, may browse and view a deck" do
    [ nil, users(:one), users(:admin) ].each do |viewer|
      policy = PresentationPolicy.new(viewer, @deck)
      assert policy.index?, "index? for #{viewer&.email.inspect}"
      assert policy.show?, "show? for #{viewer&.email.inspect}"
    end
  end

  test "nobody gets write access through this policy" do
    [ nil, users(:one), users(:admin) ].each do |viewer|
      policy = PresentationPolicy.new(viewer, @deck)
      assert_not policy.create?, "create? for #{viewer&.email.inspect}"
      assert_not policy.update?, "update? for #{viewer&.email.inspect}"
      assert_not policy.destroy?, "destroy? for #{viewer&.email.inspect}"
    end
  end

  test "the scope returns every deck" do
    assert_includes PresentationPolicy::Scope.new(users(:one), Presentation).resolve, @deck
  end
end
