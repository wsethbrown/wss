# The host's take on a pour, for tonight.
#
# A deck's pour notes are a sales pitch ("here's what you're getting, and how
# this bottle serves the story"). An event's are the host's own ("I bought
# these, here's what I think, here's what fits tonight's theme"). Same shape,
# different voice, so each keeps its own copy.
#
# Prefilled from the bottle when a pour is added, then edited freely. Edits
# NEVER travel back to the bottle: the bottle's own record comes from reviews
# and from how it was catalogued, not from what one host wrote for one night.
class AddNotesToEventBottles < ActiveRecord::Migration[8.0]
  def change
    add_column :event_bottles, :notes, :text
  end
end
