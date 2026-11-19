# Backing store for the controller `rate_limit` declarations (sign-in, magic
# links, email change, society invitations).
#
# Production/development use Rails.cache (Solid Cache in production, so limits
# hold across web processes). The test environment's cache is a null store and
# the suite signs in thousands of times from 127.0.0.1, so in test this is a
# no-op unless a test opts in with RateLimitStore.enable_for_test!, which swaps
# in a private memory store. Nothing else in the suite can reach that store.
class RateLimitStore
  class << self
    def increment(key, amount = 1, **options)
      backend&.increment(key, amount, **options)
    end

    def enable_for_test!
      @test_store = ActiveSupport::Cache::MemoryStore.new
    end

    def disable_for_test!
      @test_store = nil
    end

    private

    def backend
      Rails.env.test? ? @test_store : Rails.cache
    end
  end
end
