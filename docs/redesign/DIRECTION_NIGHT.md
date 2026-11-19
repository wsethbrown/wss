# Direction study: "The night, pour by pour"

Status: **preview only** (`/?design=next4`), for the owner to judge on screen. Nothing
here changes `DESIGN_SYSTEM.md` until the owner and advisor accept it.

## The diagnosis

The 2026 system is correct and calm, and it reads as daytime software. Nothing on the
page shows that real people sit at a table once a month, one of them stands up with a deck
they spent weeks on, and bottles get poured blind. The product's soul is the night;
the site shows a catalogue.

## The idea

**The site is structured like a WSS night.** Every night has the same arc: the
invitation, the presenter, the story, the pours, the reveal, the verdict. The homepage
walks that arc using real data from the database, and the rest of the site borrows its
grammar.

## The motif: the glass

The logo is two glasses with orange whiskey in them. That gives the orange a meaning it
lacks today: **orange is whiskey**. It is still a mark, never a fill, but now it fills
something.

- A small line-drawn glass glyph (inline SVG, 1.8 stroke, ink outline, orange liquid)
  is the site's numeral for a pour: Pour 1, 2, 3, 4.
- The liquid level can carry real meaning: RSVP fill toward the table's size, a score out
  of 5, how much of a deck you've read.
- Anything numbered by pours (a flight, a deck's pour list, an event's pours) uses it.

## The grammar: the tasting sheet

The paper ground stops being "a background" and becomes the scorecard that gets passed
round the table (the product already ships a blank scorecard download). Ruled hairlines,
numbered rows, a score column at the right in `tabular-nums`. This is the existing
"ruled list" pattern, given a reason to exist.

## The homepage arc (real data only; an act whose data is missing does not render)

1. **The invitation.** The next real public event: date and time as the headline
   ("Thursday, 7:30"), society and place, how many are coming.
2. **On deck.** Who presents and which deck: the host and the deck's real first slide.
3. **The story.** The existing deck player (keep it, it's the best thing on the page).
4. **The pours.** The event's pours as glasses, poured blind; the reveal shows
   names only when the event has ended, using the existing veiling rules.
5. **The verdict.** The room's real scores from a past blind flight: the ranked
   pours, and the surprise if there is one (lowest price ranked highest).
6. **Your table.** The offer: start a society or join one; decks by credit or outright.

## What stays

Everything in `DESIGN_SYSTEM.md` not contradicted above: palette, type, radii, no
stock photos, no invented numbers, no gradients, one green panel per view (the night
itself can be that panel: the evening is dark, the morning-after verdict is on paper).

## What needs the owner

- Real photos from real nights (the strongest single upgrade; cannot be faked).
- One founding paragraph in the owner's own words.
- Approval of every new line of copy in the study (listed in its hand-back).
