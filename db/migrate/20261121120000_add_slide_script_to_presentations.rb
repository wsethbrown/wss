# The script for each slide, as the package's speaker-notes.md split it
# ("## [SLIDE n] Title" sections), kept in slide order as
# [{ "title" => ..., "body" => ... }]. Written by DeckPackageImport, shown only
# on the admin deck page beside its slide. It is paid content: never render it
# on a buyer page. Decks loaded before this column have [] until their package
# is uploaded again.
class AddSlideScriptToPresentations < ActiveRecord::Migration[8.1]
  def change
    add_column :presentations, :slide_script, :jsonb, default: [], null: false
  end
end
