---
name: wss-deck-speaker-notes
description: Write the speaker notes for a WSS tasting-night deck (speaker-notes.md) — the host's kit for before the night (casting the bottles by role, swap-ins, pour order, set-up, running order) and the read-aloud script with one [SLIDE n] section per slide, stage directions, callouts and hedges, in the owner's voice and in the exact markdown the build tools and the site import rely on. Use when writing or editing a deck's script or notes, or when slides are added, removed or reordered. Part of the deck workflow that starts in wss-deck-creation.
---

# Writing the speaker notes

The speaker notes are a **host's kit**. Someone who has never seen this deck buys it on the
site, opens the PDF a week before their society's night, and has to be able to buy the
bottles, set the table and run a good 45 minutes from it, in their own voice. The same
script appears in the pptx's presenter view, slide by slide, and the part after the `---`
rule becomes the story on the deck's page on the site.

Write them after the research outline (`wss-deck-outline`): every fact in the script comes
from it, and what the outline lists as "Not confirmed" is said aloud as a hedge or left out.

The notes fix the deck: their `[SLIDE n]` sections decide how many slides there are and in
what order. Write the script, then build the slides to match.

## Shape

```
# Title / Speaker's notes / The Whiskey Share Society
_READ THIS FIRST ..._                          one line, green italic
## Part One: before the night                  the kit
---                                            exactly one rule
## Part Two: the script
_SET UP: ..._
## [SLIDE 1] Title ... ## [SLIDE N] Sláinte    one section per slide
```

Exact syntax, what each tool reads, and full skeletons:
[reference/markdown-dialect.md](reference/markdown-dialect.md). Read it before writing.

## Read this first

One line in green italic, under the title block: the single thing a host must know before
opening the box. The owner's examples:

- "READ THIS FIRST. The bottles in the deck are an example, not a prescription. Swap in
  whatever you can actually get."
- "POUR THE 10 YEAR EARLY. Slide 2, and keep talking. Nobody should sit through a history
  lesson with an empty glass."

## Part One: before the night

Sections, as the deck needs them (the pilot uses all of these):

- **The one-sentence version.** The story in brief. Not a thesis to prove; the owner's Mint
  Julep notes end theirs with what to remember: "remember that the bourbon is the newest thing
  in the glass."
- **What the night is.** A short paragraph on how the evening runs and its spirit (warm to the
  brands, bottles as chapters, blind or not).
- **How many bottles.** Usually three to five, and why. "Past five, palate fatigue does your
  thinking for you."
- **Cast the roles, then find the bottles.** "Every bottle on the table should be doing a job.
  Decide the jobs, then go shopping." One bullet per role: its job in the story, and tonight's
  bottle.
- **Bottle ideas by role.** Swap-ins under each role, each with a rough price, proof and one
  true line: "Suggestions, not instructions. Prices are rough, they move, and allocation varies
  wildly by state. Buy what you can actually find." Date the prices. No Jameson, ever.
- **How to order them.** Usually ascend in proof ("Palate fatigue is not symmetric"); if the
  story wants another order, say so and tell the host to say it aloud.
- **Match the deck to your lineup.** Which slides name which bottle, so a swap is one edit.
- **Set-up and a running order**: a callout with minutes against slide ranges, and anything
  to prepare (glasses marked 1 to 4, a drink batched, ice crushed, bottles hidden or not).
- Optional asides as callouts: a game, a pairing that makes the night, a caution.

Part One must contain **no `---` line**: the site import keeps everything after the first rule
as the public story, and the casting notes and prices belong to the host only.

## Part Two: the script

Start with `## Part Two: the script` and a short `_SET UP: ..._` direction. Then one section
per slide, `## [SLIDE n] Title`, numbered 1..N with no gaps; the title matches the slide's.
Insert or remove a slide and you renumber every section after it, and the running order.

The first 24 lines after the rule are the deck page's public teaser. Let them be the welcome
and the hook; never the reveal.

What goes in a section:

- **Roman text, to read aloud** "more or less as written" (the owner's notes). Short
  paragraphs; one thought each. The slide carries the line; the script carries the explanation.
- **Stage directions** as whole paragraphs in underscores, on their own: when to pour, what not
  to say yet, when to stop talking. "Pour Glass A now. Don't say what's in it yet." "They
  should be well into the 10 Year by now. Ask what they are getting before you move on." "Walk
  the list. Land hard on the third line."
- **Questions for the room** at each pour, as a direction: `_Ask: "..."_`. One question, then
  stop talking.
- **Callouts** for optional asides and host warnings, with specific imperative labels:
  SAY THE CAVEAT OUT LOUD, DO NOT OVERSELL IT, BEFORE YOU ADVANCE, THE ONE RULE. A few
  sentences each; "Boxed asides are optional — use them if it feels right, skip them if
  you're running long."
- **Pours placed in the story.** The first glass early (slide 2 is a good default). Each pour's
  section gives what it is, one or two true facts that tie it to the story, and a question.
  A reveal (if blind) follows a beat: name it, one true fact, why it sat where it sat, one
  question, stop.
- **Sláinte last**: a short toast to the people in the story, and "Sláinte." Then, if useful, a
  direction for the last pour.

### Hedging aloud

The truth standard is said in the script, not hidden in the outline:

- "The story goes that ..." for a legend with no primary source.
- "Accounts differ on when; some say the 1980s, some the early 1990s."
- "I could not settle it, so I won't pretend to." (the pilot, on where a rye is filtered)
- Say which price: shelf, secondary, or what you paid.

It costs nothing and makes everything else more believable.

### Timing

About 45 minutes for the whole night: around 1,800 to 2,400 words of script (the pilot's
script is about 1,850 words over 14 slides), plus pouring and the room talking. Check the
running order against the word count: roughly 130 words a minute read aloud.

## Voice

Plain, warm, a little dry; short sentences; the host talking to friends. Short examples from
the owner's own notes:

- "Tonight, the label doesn't get a vote."
- "Taste that first. Sit with it a second. I'll tell you what it is in about twenty minutes,
  and I want you to have an opinion before I do."
- "Heat is not flavour. If you score heat, you are just scoring proof."
- "If you pick a bad expensive bottle you have rigged the game!"
- "Years later, the only thing the future King of England could remember about Richmond was
  that julep."

Narrative first, never a gotcha. Warm to brands: "If you sneer at it, your audience stops
trusting you." Tell hard chapters (a lawsuit, a myth) plainly. People are not props: when the
story involves enslaved or marginalised people, say who did the work and that the genial
version is usually the one the powerful recorded.

Never: notes to the author, session history, "fix this", lyrics, a fact not in the outline.

### Say the thing, skip the flourish

The owner called this slide line "total AI slop writing": "A recipe built to be the seasoning,
never the dish." It was a fact (the rye was made to go into blends) dressed up as a quotable
line. Write the fact. The patterns to cut, on slides and in the script:

- **The aphorism that closes a section.** "It was never supposed to be the dish." "The name on
  the front and the name on the still are the same." End on the last fact instead.
- **The metaphor standing in for a plain statement.** "The grain talking", "the distillery
  speaks for itself", "never knew its address". Say "comes from the grain", "the distillery's
  own bottle", "did not know where it was made".
- **The set-up before the point.** "Here is the strange part." "What happened next is the
  better part of the story." Delete it and start with the point.
- **Balanced pairs and triplets written for rhythm.** "A building you have never heard of, in
  a town you have never been to, that has been in your glass."
- **Claims about the people in the room.** The owner on "Most of you have had this rye. Very
  few of you have been to the place it was made": "what a stupid statement. You don't know if
  people have had the rye or if they've been to the distillery." The writer has never met the
  room. Do not say what the audience has drunk, knows, expects or has heard of ("the one you
  know", "you have almost certainly", "everyone remembers"). State what the bottle is, or ask.
- **Predictions about the room, and host directions on a slide.** A slide once read "Ask the
  room to guess the year. They will guess too late." The owner: "#1 don't ever make
  declarations like this #2 don't put this IN the slide where everyone can see it." Directions
  to the host go in the script as stage directions, never in slide text, and never say how the
  room will answer. That covers the glass line and the question too: a slide once carried
  "Glass 1. Pour it now." and an "Ask the room  What do you smell?" strip, and the owner said
  "We shouldn't have these types of callouts ON the slides." The slide says "Glass 1"; the
  pour, the question and "keep some for the next glass" are `_..._` directions here.
- **Labels and captions built as one long noun phrase.** "Joseph Fleischman, who worked in
  the trade, on the man ordering whiskey at a bar, 1885" and "Col. E. H. Taylor Jr., the
  Kentucky distiller historians credit with pushing for it" (the owner: "it reads weird").
  Name the person or the source, stop, then say the rest as a sentence: "Col. E. H. Taylor
  Jr., a Kentucky distiller. Historians credit him with pushing for the Act." Quote enough
  of a sentence that it stands without a caption explaining who it is about. A source note
  is "Source: Maker's Mark.", not "Published by the maker."
- **"Tonight: Maker's Mark."** in the kit's list of glasses. The host may pour something
  else, so the script names a suggestion: "Suggested bottle: Maker's Mark." (the owner's
  wording; "Our recommendation" is the other form they offered).
- **British spelling in an American deck.** "All of the colour comes from the wood." The
  owner: use American spelling unless it is a quote or the topic is British. See CLAUDE.md,
  "Spelling: American"; `tools/decks/american.py` converts a file outside its quotations.
- **A label above a heading that only announces it.** "The first word on the label" over
  "What 'bourbon' means." Cut the label. Also cut the corrective pair on a slide: "It was a
  resolution, not a law." Give the fact: "Senate Concurrent Resolution 19, May 1964".
- **A sentence that leaves a question open.** "He never saw this written down" (the owner:
  "what is 'this'"); "Roosevelt has waited years for someone to put that in print" ("why?").
  If a line makes the reader ask what or why, answer it in the line or cut it.
- **Fragments stacked for drama.** "1791. The first federal tax ever laid on something
  Americans made themselves." Write the sentence: "In 1791 Congress put a tax on American-made
  spirits."
- **A motif repeated for effect.** The pilot said "four different hands" five times.

This applies to text carried over from an older deck as much as to new writing: "keep the
owner's content" means keep the facts, the story and the bottles, not the phrasing. The owner
flagged a whole deck of carried-over lines as slop.

The owner's own good lines are plain statements a host would actually say to friends ("Heat is
not flavour."). If a line sounds like a caption on a poster, rewrite it as what you would say
across the table. Read every slide's text on its own before building: a slide shows one
sentence at a time, so a flourish has nowhere to hide.

## Into the pptx

You do not paste anything. `tools/decks/build.py` reads `speaker-notes.md`, finds each
`## [SLIDE n] Title` section and writes `[SLIDE n] Title` plus the section's text into slide n's
notes field: stage directions become `[CUE] ...`, callouts `[LABEL] ...`, bold and italic
markers are stripped. It refuses to build if the deck's slide count and the sections disagree,
and it checks every notes field is filled and the file has exactly one `---`.

After building, open the pptx notes of slide 1, a pour slide and the last slide and read them.

## Editing an existing script

The owner edits the markdown directly. Before rebuilding from a copy you hold, diff it against
the current file: never overwrite their paragraphs with an older version. Make the change in
the markdown, rebuild everything, and never patch the PDF or the pptx by hand.

## Checklist

- READ THIS FIRST line; Part One with roles, swap-ins (dated prices), order, running order.
- Exactly one `---`; Part One has none; the first 24 script lines give nothing away.
- `[SLIDE n]` sections = slides, numbered 1..N, titles match the slides.
- Every pour has a stage direction to pour it and a question for the room.
- Every unconfirmed claim is hedged aloud or absent; no Jameson; no lyrics.
- Script length fits the running order.
