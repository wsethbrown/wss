# The deck's subtitle ("Cocktails, Chapter One"), shown on the deck page under
# the title. Every package's deck.json already carries one; DeckPackageImport
# fills it, and the admin can type it on the Listing tab. Optional.
class AddSubtitleToPresentations < ActiveRecord::Migration[8.1]
  def change
    add_column :presentations, :subtitle, :string
  end
end
