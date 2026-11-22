# The deck page's extra sections, in order: [{ "heading" => String,
# "lines" => [String] }]. Typed on the admin Listing tab or filled from a
# package's deck.json, rendered on the deck page where "What you'll taste" used
# to be (see Presentation#sections= and presentations/_extra_sections). They
# replace the four fixed tasting boxes; CarryTastingNotesIntoSections moves the
# old notes into a section.
class AddSectionsToPresentations < ActiveRecord::Migration[8.1]
  def change
    add_column :presentations, :sections, :jsonb, default: [], null: false
  end
end
