---
name: wss-deck-outline
description: Research a WSS tasting-night deck and write its research outline (research-outline.md) — search planning, primary sources first, what to do when pages cannot be fetched, dated facts, the outline's modules, sources, not-confirmed list and image credits, in the owner's voice. Use for the research step of any new deck, for fact-checking an existing one, or when asked for a research outline. Part of the deck workflow that starts in wss-deck-creation.
---

# Researching a deck and writing its outline

The outline is "the other half of the speaker notes" (the owner's phrase). The notes tell a
host what to say; the outline tells **anyone who wants to rebuild the night in their own
voice** where to look, what is settled, what is still argued about, and which repeated
"facts" will embarrass them. It is also the deck's evidence: every fact on a slide or in the
script must be traceable to it.

Write it **before** the speaker notes. The script is written from the outline, not the other
way round.

## Research: the hard line

"You need to do thorough research." Facts from memory are not acceptable, however sure you
feel. Memory is where to start looking, never the source. Everything in "What's established"
was found in a source during this deck's research, and the source is listed.

### Plan the searches before you start

1. Write the story's spine as a chain of claims with dates (A in 1847 → B in 1933 → ...).
2. List every claim the night will lean on: dates, names, places, numbers, laws, who did what,
   every quotation, and for each bottle its maker, where it is distilled, proof, mash bill or
   cask, age statement, current availability and approximate price.
3. Mark the **load-bearing** ones: the claims the story turns on, anything surprising, anything
   that would be embarrassing if wrong. Those get two independent sources.
4. Set a budget: roughly 40 to 80 searches for a full deck. Spend most of it on the load-bearing
   claims and the bottles; stop chasing colour that the story does not need.

Use the WebSearch tool (load it with ToolSearch, `select:WebSearch`); WebFetch for a page when
it is allowed. Search with specific words: names, years, exact product names, statute numbers.

### Sources, best first

1. **Primary documents and official bodies**: statutes and regulations (eCFR, law.cornell.edu),
   the TTB and its public COLA label registry, SEC filings, court records and settlements,
   contemporary newspapers (Chronicling America, state digital newspaper archives), government
   archives, the Scotch Whisky Association, Japan's spirits makers' standard.
2. **Named historians and established whisky writers**, books and long-form articles.
3. **The maker's own statements**: good for what a bottle is (proof, recipe, age), weak for the
   maker's own history and legends.
4. Reference works (Wikipedia is a map to its citations: follow them, cite what you reach).
5. A blog or a retailer page alone is not enough for anything that matters. Retailer listings
   are fine for current shelf prices, dated.

The owner's own outline on why: "Chase the primary sources. Cocktail history is unusually
infested with blog posts citing blog posts, and the underlying documents are almost all
digitized and sitting there for free."

### When a page cannot be fetched

Fetching is often blocked or rate-limited. Then: work from the search results' titles and
snippets, search again with different words to get the fact stated in another result, and
look for the same fact from a second publisher. Cite what you actually saw (title, publisher,
date, URL). If a claim rests on one snippet you could not open, it goes in **Not confirmed**,
or is said aloud as "one account says". Never cite a document you have not seen any of.

### Dated facts

- Every fact that moves is dated: prices, availability, who owns what, which brand sources
  from where, current proof and label. Write "checked November 2026".
- Prices are approximate US shelf prices, labelled as such. The owner: "say which price you're
  using, shelf, secondary, or what you actually paid."
- When sources disagree, say so and give both; put the better-supported one on the slide, or
  no single answer (the pilot gives no year for the 95/5 recipe because accounts differ).
- Legends stay legends, labelled with what the evidence is. "If a claim can't be traced past a
  blog post, it goes on the slide as 'the story goes…' and not as a fact."

## The outline's audience and stance

- Addressed to **anyone rebuilding the night**, never to "the presenter". Never "your deck",
  "your slide", "fix this before you present", "the deck currently says".
- Never tells the reader what to conclude, never snipes at other writers. State the facts,
  cite the documents, name the traps, and let them land where the evidence takes them.
  The owner's Mint Julep outline: "the sources are listed so you can weigh them yourself and
  land wherever they take you."
- No notes-to-self, no session history ("I changed this from..."). It reads as if it was always
  this way.

## Sections

In this order (the pilot, `tools/decks/examples/the-rye-from-lawrenceburg/research-outline.md`,
is a full example):

1. **Title block**: `# Title`, then `Research outline: <subtitle>`.
2. **What this is**, one italic paragraph: the other half of the notes; facts checked in
   <month year>; what moves quickly and should be re-checked.
3. **The spine of the story**, a callout: the chain of events with dates and arrows.
4. **How to use this**: what each module holds, and the standard of proof.
5. **Modules**, one per chapter of the story (usually five to eight), each with:
   - the **question worth answering**, as a green-italic line under the heading;
   - **What's established**: dated, sourced facts, bold year first (`- **1933.** ...`);
   - **Go to the source**: `- › _..._` lines, free and online first, saying what each gives;
   - **Threads worth pulling** (optional): open questions someone could chase;
   - a **Traps** callout: the claim that trips people up, and what is true.
6. **Bottle facts**: a module (or one per bottle) with each pour and its swap-ins: maker,
   where distilled, proof, recipe or cask, age, approximate price with the date checked, and
   current availability where it is uncertain.
7. **Claims that don't hold up**: short, plain corrections.
8. **The short shelf**: the five things to read first.
9. **Not confirmed**: every claim that could not be confirmed, what was found, and how the
   script handles it ("said as 'the story goes'", "kept off the slides").
10. **Sources**: everything cited, title, publisher, date, URL.
11. **Image credits**, last: per slide, the title, author or institution, licence, where it was
    found (e.g. the Commons file name), and what was changed ("Cropped and printed in two
    inks"). Then any slide left with a placeholder because no free image exists.

## Tone

Plain, dry, specific, generous to the reader. Short quoted examples from the owner's outlines:

- "Each one is a night's reading, not a semester."
- "This is a genuine hole in the record, not a fact I'm withholding."
- "Find the 11 Jan 1770 poem yourself; it takes ten minutes."
- "Davis is cited as 'the first mention' in roughly every article ever written. It is at least
  the fifth." (a trap stated as a finding, with the evidence, not as a sneer)
- "A bad expensive bottle proves nothing. Every bottle on the table should be one you'd
  happily drink."

Traps are labelled specifically and imperatively where it helps: TRAPS, DO NOT OVERSELL IT,
BUT DON'T OVERCLAIM IT. Keep each callout to a few sentences.

## Markdown

The PDF is built by `tools/decks/pdfs.py`, which reads a small dialect: `## Module n. Title`
for modules, `### ` subheadings, `- › _source_` lines, `> **LABEL**` callouts, whole-paragraph
`_italics_` for the question lines. No tables, numbered lists or links. Full list:
`.claude/skills/wss-deck-speaker-notes/reference/markdown-dialect.md`.

## Before handing back

- Every fact in the script and on the slides is in "What's established" or explicitly hedged.
- "Not confirmed" is honest and complete; nothing in it appears on a slide as fact.
- No Jameson bottle anywhere; no song lyrics; every image credited with its licence.
- Prices and availability carry a date.
- Hand back a short list: corrections you made to the story as first imagined, the load-bearing
  facts and their sources, and what stays unconfirmed.
