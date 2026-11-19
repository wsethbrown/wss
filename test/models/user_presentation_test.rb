require "test_helper"
require Rails.root.join("db/migrate/20261119140000_add_unique_index_to_user_presentations.rb")

# B7 / M2: one ownership row per (user, deck), enforced by the database.
class UserPresentationTest < ActiveSupport::TestCase
  setup do
    @user = users(:john)
    @deck = Presentation.create!(author: users(:admin), title: "Ownership Deck", content: "Story.", price: 10)
  end

  test "the database refuses a second ownership row for the same user and deck" do
    UserPresentation.create!(user: @user, presentation: @deck, purchase_type: "credit", purchased_at: Time.current)
    assert_raises(ActiveRecord::RecordNotUnique) do
      UserPresentation.create!(user: @user, presentation: @deck, purchase_type: "direct", purchased_at: Time.current)
    end
  end

  # --- the data migration's duplicate merge ----------------------------------
  def with_duplicates
    ActiveRecord::Base.connection.remove_index :user_presentations, name: AddUniqueIndexToUserPresentations::INDEX_NAME
    yield
  end

  def insert_row(type, created_at, price: nil)
    UserPresentation.insert!({ user_id: @user.id, presentation_id: @deck.id, purchase_type: type,
                               purchase_price: price, purchased_at: created_at,
                               created_at: created_at, updated_at: created_at }).rows.flatten.first
  end

  def merge
    ActiveRecord::Migration.suppress_messages { AddUniqueIndexToUserPresentations.new.merge_duplicates }
  end

  test "merge keeps the direct row over a credit row, even when the credit row is older" do
    with_duplicates do
      credit_id = insert_row("credit", 3.days.ago)
      direct_id = insert_row("direct", 1.day.ago, price: 10)
      merge
      assert_equal [ direct_id ], UserPresentation.where(user: @user, presentation: @deck).pluck(:id)
      assert_not_equal credit_id, direct_id
    end
  end

  test "merge keeps the oldest row when the duplicates are the same type" do
    with_duplicates do
      oldest = insert_row("direct", 5.days.ago, price: 10)
      insert_row("direct", 2.days.ago, price: 10)
      insert_row("direct", 1.day.ago, price: 10)
      merge
      assert_equal [ oldest ], UserPresentation.where(user: @user, presentation: @deck).pluck(:id)
    end
  end

  test "merge leaves other users' and other decks' rows alone" do
    other_deck = Presentation.create!(author: users(:admin), title: "Other Deck", content: "Story.", price: 10)
    with_duplicates do
      insert_row("credit", 2.days.ago)
      insert_row("credit", 1.day.ago)
      UserPresentation.create!(user: users(:jane), presentation: @deck, purchase_type: "credit", purchased_at: Time.current)
      UserPresentation.create!(user: @user, presentation: other_deck, purchase_type: "credit", purchased_at: Time.current)
      assert_difference -> { UserPresentation.count }, -1 do
        merge
      end
    end
  end
end
