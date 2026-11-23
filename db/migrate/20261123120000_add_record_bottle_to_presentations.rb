# A deck's review bottle: when the deck is the one featured on the homepage,
# the tasting record leads with the newest public review of this bottle
# (HomepageFeature). Optional. No two decks share one, so the decks the
# homepage rotates through never show the same bottle; removing a bottle from
# the catalog just clears the choice.
class AddRecordBottleToPresentations < ActiveRecord::Migration[8.1]
  def change
    add_reference :presentations, :record_bottle, null: true,
                  foreign_key: { to_table: :bottles, on_delete: :nullify },
                  index: { unique: true, where: "record_bottle_id IS NOT NULL" }
  end
end
