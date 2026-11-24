# Decks the owner marks as included with membership: any member with an active
# membership opens them without spending a credit or buying them; everyone
# else pays the price. Access is decided in User#can_access_presentation?.
class AddIncludedWithMembershipToPresentations < ActiveRecord::Migration[8.1]
  def change
    add_column :presentations, :included_with_membership, :boolean, default: false, null: false
  end
end
