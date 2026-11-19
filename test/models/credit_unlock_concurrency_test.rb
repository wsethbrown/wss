require "test_helper"

# B18: B7's double-unlock test ran its two calls one after the other. This one
# races them. Two threads, each on its own database connection, hit
# CreditTransaction.use_credit for the same user and deck at the same instant.
# The user row lock (and the unique index behind it) must let exactly one win.
#
# Transactions are off for this class: a wrapping test transaction would put
# both threads on one connection's view of the data and hide the race. So the
# test builds its own rows and deletes them itself.
class CreditUnlockConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  # Parallel workers each have their own database, so this stays isolated.

  setup do
    @user = User.create!(email: "race-#{SecureRandom.hex(4)}@example.com", password: "password123",
                         password_confirmation: "password123", first_name: "Race", last_name: "Test")
    @author = User.create!(email: "race-author-#{SecureRandom.hex(4)}@example.com", password: "password123",
                           password_confirmation: "password123", first_name: "Race", last_name: "Author")
    @deck = Presentation.create!(author: @author, title: "Race Deck #{SecureRandom.hex(3)}", content: "Story.", price: 10)
    CreditTransaction.record!(user: @user, amount: 2, transaction_type: "granted", description: "race setup")
  end

  teardown do
    # The ledger is append-only at the model layer, so clean up with SQL.
    UserPresentation.where(user_id: @user.id).delete_all
    CreditTransaction.where(user_id: @user.id).delete_all
    @deck.destroy
    @user.destroy
    @author.destroy
  end

  test "two simultaneous unlocks of one deck spend one credit and create one ownership row" do
    barrier = Queue.new
    ready = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          user = User.find(@user.id)
          deck = Presentation.find(@deck.id)
          ready << true
          barrier.pop # released together below
          results << CreditTransaction.use_credit(user, deck)
        rescue => e
          results << e
        end
      end
    end

    2.times { ready.pop }
    2.times { barrier << :go }
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }
    errors = outcomes.grep(Exception)
    assert_empty errors, "a racing unlock must refuse cleanly, never raise: #{errors.map(&:message)}"
    assert_equal [ false, true ], outcomes.sort_by(&:to_s), "exactly one unlock wins"

    assert_equal 1, UserPresentation.where(user_id: @user.id, presentation_id: @deck.id).count
    assert_equal 1, CreditTransaction.where(user_id: @user.id, transaction_type: "used").count
    assert_equal 1, @user.reload.credits, "one of the two credits was spent"
    assert_equal CreditTransaction.balance_for(@user), @user.credits, "cache equals the ledger"
  end
end
