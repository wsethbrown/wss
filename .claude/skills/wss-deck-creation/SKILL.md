---
name: wss-deck-creation
description: Make a WSS tasting-night deck package — choosing the story and the bottles, the slides, the build with tools/decks, QA, and loading it into the site as a draft. The entry point for any new deck or a rework of one; it hands off to wss-deck-outline (research) and wss-deck-speaker-notes (the script). Use whenever someone asks for a deck, a presentation, a tasting night, slides, or a new title for the library. For the site side (import, rendering, the teaser gate) see wss-deck-pipeline.
---

# Making a WSS deck

A WSS deck is one tasting night: someone in a society stands up, tells an interesting story
about whiskey, and the room drinks bottles that belong to that story. The site sells the
package, so a stranger has to be able to pick it up and run a good night in their own voice.

## What the owner wants (read this before anything else)

In the owner's words:

- "The goal of the presentations is to focus on a specific topic of whiskey and present an
  interesting narrative throughline." "Specific bottles need to be presented in conjunction,
  so a presentation like 'the barrel' may not have anything specific to focus on."
- "your presentations are all historical but there are WAY more interesting themes, and
  'historical' topics are more akin to beginner things. People who are highly interested in
  whiskey already know about the bond act and what happens to barrels etc"
- "there doesn't have to be an 'argument'. These decks are not gotchas or confrontational.
  They're narrative first - tell an INTERESTING story about whiskey and present bottles that
  reflect and/or are directly related to that story."
- "You can tell the history and pour alongside it, that's fine." "The look is changeable -
  I don't necessarily love the old look." "You do NOT have to emulate those 3 decks strictly.
  They are a small sample of many styles the site can and will use."
- "These 'rules' I'm giving you about deck creation aren't hard and fast. There are always
  exceptions to the rules."
- "You need to do thorough research." Facts from memory are not acceptable.
  "Take jameson out of the presentations. Hate that brand."

So every guideline below is a **default with its reason**. Break one when the story is
better for it, and say in your hand-back which one and why.

### The hard lines (no exceptions)

1. **Researched, not remembered.** Every fact is checked against sources found for this deck
   and listed in the outline, with an honest "Not confirmed" list. Method: `wss-deck-outline`.
2. **Nothing fabricated**: no invented facts, quotes, prices, tasting results, reviews or people.
3. **No Jameson**: not poured, not suggested as a swap. Name the firm only where a history
   cannot be told without it.
4. **Image rights**: public-domain, freely licensed (credited as the licence asks) or
   owner-supplied photos only, each credited in the outline. No manufacturer press shots
   unless the owner says so. No copyrighted maps. No image found: a clean placeholder.
5. **No song lyrics**, ever. Poems only as short public-domain excerpts, cited.
6. **The three artifacts stay in sync**: slide n is `[SLIDE n]` in the notes, and the whole
   script sits in the pptx notes fields. The markdown is the source of truth; never hand-edit
   a PDF or the pptx.

### Build one, show it, then build more

The owner redirected the approach three times in one day. **Build one deck, put it in front
of the owner, and wait for their reaction before starting a second.** A batch built on a
misread brief is a batch thrown away.

## What a package is

| File | Made from | For |
|---|---|---|
| `speaker-notes.md` | written by hand (`wss-deck-speaker-notes`) | the host: before-the-night kit, then the script |
| `research-outline.md` | written by hand (`wss-deck-outline`) | anyone rebuilding the night; sources, not-confirmed list, image credits |
| `deck.json` | written by hand | the site: slug, title, subtitle, category, difficulty, duration, description, tags, pours, takeaways, sections |
| `slides.py` + `assets/` | written by hand, using `tools/decks/wsskit.py` | the slides and their images |
| `<slug>.pptx` | built | the room; opens in Keynote and PowerPoint |
| `<slug>-speaker-notes.pdf`, `<slug>-research-outline.pdf` | built | owner downloads on the site |
| `slides/slide-NN.png` | built | QA, and the slide images and cover on the site |

The worked example is `tools/decks/examples/the-rye-from-lawrenceburg/` (sources only;
build it to see the outputs). `deck.json` fields: `difficulty` is Beginner, Intermediate or
Advanced; `tags` is one comma-separated string; each pour is
`{name, origin, style, strength, notes}`; no `price` (see Pricing).

`subtitle` is customer copy too: it shows on the deck page as one line under the title (not on
the library card). Up to 140 characters; write it for buyers ("Cocktails, Chapter One", "What the
words on the label mean") and propose it to the owner with the rest of the deck's wording.

Two more keys fill the rest of the customer's deck page, so nobody types them at upload:

- `takeaways`: the "What you'll learn" list, `[{"title": "...", "text": "..."}]`. Up to 10;
  a title of up to 120 characters, a one-sentence text of up to 400, on one line each, and the
  text must not start with `-`, `*` or a bullet. Three or four is usual.
- `sections`: the deck's extra sections, shown after the story where "What you'll taste" used
  to be, `[{"heading": "...", "lines": ["...", "..."]}]`. Up to 8 sections, a heading of up to
  80 characters, up to 12 lines of up to 300 characters each. Plain text, no Markdown. A line
  `"Label: text"` (label up to 24 characters) shows as a labelled row (`"Nose: vanilla and oak"`,
  `"Glass A: handed out at slide 2"`); a section with one plain line shows as a short paragraph;
  otherwise the lines are a list. Use them for what suits this deck (what you'll need, who it is
  for, the tasting profile of a single-bottle night, the running order of the glasses), not as
  a fixed set. None is fine.

Draft them (and the subtitle) when the deck is made, in the same step as the description, from the outline and the
script (nothing in them that the outline does not establish). They are customer copy: propose
their wording to the owner for approval with the rest of the deck's wording, never write them
straight into a deck the owner has not seen. `build.py` checks their shape and limits and fails
before building; the site refuses a package that breaks them. Leaving a key out means a
re-upload keeps whatever the admin typed on the deck page; an empty list clears it.

## Choosing the story and the bottles

The audience is enthusiasts. They know what a barrel does, what bottled in bond means and
how bourbon is made. Explain only the thing your story turns on.

A good topic is **specific** and **pourable**: there is a story with people, places and turns
in it, and there are real, currently available bottles that sit inside that story. Test:
could you name the four bottles before writing a word? If the bottles are "any bourbon",
the topic is too broad (the owner's example: "the barrel").

Styles the site already has or wants. These are examples, not templates; mix them.

| Style | Example | What carries the night |
|---|---|---|
| Blind flight around a question | "A Story Someone Else Wrote" (Value vs Prestige) | Bottles cast by role, tasted blind, revealed one by one. A mirror, not a gotcha. |
| Category or place story | "Whisky From Japan" | Pour early, the history while they drink, then a turn about what is actually in the glass. |
| Cocktail chapter | "Mint Julep, Cocktails Chapter One" | Two versions of a drink made for the room; the drink's real history; build it at home. |
| Distillery story, history with pours | "The Rye From Lawrenceburg" (the pilot) | One distillery's rye in four different brands' hands, each glass arriving where it sits in the story. |

Other directions worth trying (none built yet): one person's career told through bottles they
made; one recipe or mash bill across makers; a region or style compared across countries; a
production choice you can taste side by side; a revival or a lost style brought back. History
is fine as the vehicle ("tell the history and pour alongside it"); history *as the topic*
(a law, a process everyone knows) reads as beginner material.

Bottles:

- Three to five pours (palate fatigue past five). Each has a **role** in the story.
- Real, currently sold in the US, findable in a good shop; check current label, proof and
  approximate shelf price, and date the check. Give swap-ins for each role in the notes.
- Usually ascend in proof; when the story wants a different order, say so out loud.
- A blind element only when it adds fun. No "verdict" table.
- Warm and fair to every brand. Hard chapters (a lawsuit, a myth) are told plainly.

## Slide structure (defaults)

- **Slide 1**: the title slide. Logo, the deck's name, a one-sentence hook that makes the room
  want the story.
- **Last slide: Sláinte**, the logo back, a short closing thought (a toast, not a ruling).
  Nothing after it: no sources, no "questions?".
- **One idea per slide**, short. The slide carries the line; the notes carry the explanation.
  Real editable text, never a picture of text.
- **Pours where they belong in the story**, not stacked at the end. Pour the first glass early
  (slide 2 is a good default) so nobody sits through history with an empty glass.
- Headings are sentences or short phrases that say something ("A rye made to disappear."),
  not labels.
- No notes-to-self on slides ("retitle this"); corrections go in the notes or outline.
- About 45 minutes; 12 to 18 slides has worked.

## Design

The look is open. The owner's three decks are three different looks and the old dark-brown /
burnt-orange one is not required. Whatever the look, it should sit comfortably with the site
(`wss-design-system`): the logo, paper `#F6F4EE`, bottle green `#16332A`, logo orange `#FF6D00`
as a small mark only (never text on a light ground), no yellow or amber, no gradients or glass.

The pilot's look is the current default and is what `wsskit.py` draws: paper content slides,
green for the title, Sláinte and one story slide; white hairline cards; big-year history
slides; a bottle slide with photo or placeholder, meta line, three short facts and an "Ask the
room" strip. Fonts are Avenir Next and Georgia (standard in Keynote on a Mac; the build
substitutes open fonts for rendering). Measured specs of all four looks:
[reference/house-style.md](reference/house-style.md).

Departing from it: write your own helpers or palette in `slides.py`; keep the sync rules.

## Build

Tools: `tools/decks/` (install steps in its README). Sources go in a folder of their own:

```bash
cp -r tools/decks/examples/the-rye-from-lawrenceburg <src>/<deck>   # then rewrite every file
python3 -I tools/decks/build.py <src>/<deck> tmp/decks                # tmp/ is gitignored
```

`build.py` writes `<out_root>/<slug>/` (pptx with the script in every notes field, both PDFs,
`slides/slide-NN.png`, copies of the sources) and fails if the slide count and the `[SLIDE n]`
sections disagree, a notes field is empty, a PNG is missing, or the notes do not have exactly
one `---` rule. Images: `tools/decks/duotone.py` crops a photo to its frame (and optionally
prints it in green and cream); `tools/decks/commons_search.py` finds freely licensed images
and prints their licence (Commons rate-limits; keep searches few and specific).

Never commit built files (pptx, PDFs, PNGs). Ask the owner where a finished deck's sources
should live; never leave them only in a scratch directory.

## QA (before showing anyone)

1. **Look at every slide PNG**, one by one, at full size. Overlaps, text running off a card,
   orphaned words in headings, a caption over a face, a placeholder you forgot. A passing build
   says nothing about how slides look.
2. Counts match: slides = `[SLIDE n]` sections = PNGs (the build checks; confirm the number).
3. Open the pptx notes for two or three slides and read them: script present, right slide.
4. The pptx opens cleanly (the build re-opens it; if you can, open it in Keynote or PowerPoint).
5. Read both PDFs' first pages: header band, title, no stray "UNTITLED" or template text.
6. Re-read the script against the outline: every fact on a slide is in "What's established"
   or hedged; nothing in "Not confirmed" is stated as fact; no Jameson; every image credited.

## Loading into the site

`bin/rails decks:load DIR=tmp/decks` imports every package folder in it as an **unpublished
draft** (under Docker, run it inside the web container, e.g. `./wss bash`; the repo's `tmp/`
is mounted there, a folder elsewhere on the host is not): story from the
script, pptx as the buyer download, the PDFs as owner downloads, slide 1 as the cover, the
PNGs as slide images, pours and tags. Re-running updates the same deck by title. Humans
publish; do not pass `PUBLISH=1` unless the owner asks. Details: `wss-deck-pipeline`.

## Pricing

The owner's call. Leave `price` out of `deck.json` (the import uses a default for new drafts
and never changes an existing deck's price) and do not suggest a price unless asked.

## Order of work

1. Agree the story and the bottles with the owner in a few lines, before research.
2. Research and write the outline: `wss-deck-outline`.
3. Write the speaker notes from the outline: `wss-deck-speaker-notes`. The script fixes the
   slide count and order.
4. Write `deck.json` (description, takeaways and sections drafted together, for the owner's
   approval) and `slides.py`, gather and credit images.
5. Build, QA, fix, rebuild.
6. Show the owner this one deck. Load it as a draft only when they are happy.

## Reference

- [reference/house-style.md](reference/house-style.md): the owner's three decks measured, the
  package defaults, the pilot's choices.
- `.claude/skills/wss-deck-speaker-notes/reference/markdown-dialect.md`: what the tools read.
- `tools/decks/README.md`: install and commands.
