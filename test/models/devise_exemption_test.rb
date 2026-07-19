require "test_helper"

# .bundler-audit.yml waives two Devise advisories on the grounds that the
# modules carrying them are not enabled. That reasoning has to stay true, and
# nobody re-reads a YAML comment. If someone enables :confirmable or
# :timeoutable, this fails and points at the file to fix.
class DeviseExemptionTest < ActiveSupport::TestCase
  WAIVED_MODULES = %i[confirmable timeoutable].freeze

  test "the waived Devise advisories still do not apply to us" do
    enabled = User.devise_modules

    WAIVED_MODULES.each do |mod|
      assert_not_includes enabled, mod, <<~WHY
        User now enables Devise's :#{mod}, but .bundler-audit.yml waives a
        #{mod} advisory on the grounds that we don't. Either upgrade Devise to
        5.x (the real fix) or remove that waiver so CI flags it again.
      WHY
    end
  end

  # Devise.timeout_in is 30.minutes by default whether or not we set it, so it
  # proves nothing on its own: the handler only runs for a model that includes
  # Timeoutable. Check every Devise model, not just User, so adding a second
  # one can't reintroduce the vulnerable path unnoticed.
  test "no Devise model anywhere enables the waived modules" do
    models = Devise.mappings.values.map(&:to)

    models.each do |model|
      WAIVED_MODULES.each do |mod|
        assert_not_includes model.devise_modules, mod,
                            "#{model} enables :#{mod}; revisit the waiver in .bundler-audit.yml"
      end
    end
  end
end
