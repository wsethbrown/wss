require "test_helper"

class Auth::MagicLinkServiceTest < ActiveSupport::TestCase
  test "deliver stores a hashed token for an existing user and does not leak the raw token" do
    user = users(:john)
    result = Auth::MagicLinkService.deliver(user.email)

    assert result.success?
    user.reload
    assert user.magic_link_token.present?
    assert user.magic_link_sent_at.present?
    # Only a digest is stored, never a raw/guessable token.
    assert_equal 64, user.magic_link_token.length
  end

  test "deliver rejects an invalid email" do
    result = Auth::MagicLinkService.deliver("not-an-email")
    assert_not result.success?
  end

  test "consume signs in an existing user once, then invalidates the token" do
    user = users(:john)
    raw = "raw-token-abc"
    user.update!(magic_link_token: Auth::MagicLinkService.digest(raw), magic_link_sent_at: Time.current)

    assert_equal user, Auth::MagicLinkService.consume(raw)
    assert_nil user.reload.magic_link_token, "token should be cleared after use"
    assert_nil Auth::MagicLinkService.consume(raw), "a used token cannot be reused"
  end

  test "consume rejects an expired token" do
    user = users(:john)
    raw = "raw-token-expired"
    user.update!(magic_link_token: Auth::MagicLinkService.digest(raw), magic_link_sent_at: 20.minutes.ago)

    assert_nil Auth::MagicLinkService.consume(raw)
  end

  test "a new-user token creates nothing until the sign-up is completed, then works once" do
    # The new-user token lives in Rails.cache; the test env defaults to :null_store,
    # so swap in a real store for this test (prod/dev use solid_cache/memory).
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    email = "newcomer@example.com"
    raw = "raw-token-new"
    Rails.cache.write(Auth::MagicLinkService.cache_key(Auth::MagicLinkService.digest(raw)),
                      { email: email }, expires_in: 15.minutes)

    assert_no_difference -> { User.count } do
      assert_nil Auth::MagicLinkService.consume(raw), "opening the link never creates an account"
      assert Auth::MagicLinkService.pending_sign_up?(raw)
    end

    assert_difference -> { User.count }, 1 do
      user = Auth::MagicLinkService.complete_sign_up(raw).user
      assert_equal email, user.email
      assert_not user.password_set_manually
    end
    assert_not Auth::MagicLinkService.pending_sign_up?(raw)
    assert_nil Auth::MagicLinkService.complete_sign_up(raw), "a sign-up link works once"
  ensure
    Rails.cache = original_cache
  end

  test "delivering to an unknown address creates no user" do
    assert_no_difference -> { User.count } do
      assert Auth::MagicLinkService.deliver("brand.new@example.com").success?
    end
  end

  test "consume returns nil for a blank or unknown token" do
    assert_nil Auth::MagicLinkService.consume(nil)
    assert_nil Auth::MagicLinkService.consume("does-not-exist")
  end
end
