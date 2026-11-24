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

The general rules for any research (when to search, which sources to trust, and how to
label what is sourced, inferred and uncertain) are in the `wss-research` skill. Read it
first; this section adds what is particular to a deck.

"You need to do thorough research." Facts from memory are not acceptable, however sure you
feel. Memory is where to start looking, never the source. Everything in "What's established"
was found in a source during this deck's research, and the source is listed.

### The bar: read the sources

The owner, setting the standard:

> "These presentations take a lot of research, pulling from books, journals, and articles
> written by historians and enthusiasts alike. For instance, the mint julep deck pulls a lot
> from historical newspapers and official sources and tells the story of how black enslaved
> men really created the mint julep."

So the default is plain: **read the sources; do not cite from search snippets.** A claim's
source is something you opened and read. A search result is a pointer to a source, not the
source. The reason is practical as well as principled: snippets drop the date, the hedge and
the next sentence, and in drinks history the next sentence is often "the story goes".

- In the outline, every source line says how far it was read: **read in full**, **read in
  part** (say which part: "pp. 284–288", "the 1919–1933 timeline"), or **not read** (seen
  cited elsewhere; give where). A claim that rests only on a "not read" source goes in
  **Not confirmed**.
- The best story is usually in the primary layer: old newspapers, county histories, trade
  journals, court papers, filings. The brochure history is what is left when those are
  summarised by people selling something. Go to the documents first and read the brochure
  to see what it leaves out.
- People are not props. When the history involves labour, ownership, enslaved or excluded
  people, or a community the brochure version skips, record what the sources say about them,
  with the same care as the dates.
- The search budget below still applies. Fetching and reading documents is not a search;
  that is where the time should go.

Working recipes for each archive (exact URL patterns, what refuses automated clients, and
the fallbacks) are in **`reference/research-recipes.md`**. Read it before you start.

### Plan the searches before you start

1. Write the story's spine as a chain of claims with dates (A in 1847 → B in 1933 → ...).
2. List every claim the night will lean on: dates, names, places, numbers, laws, who did what,
   every quotation, and for each bottle its maker, where it is distilled, proof, mash bill or
   cask, age statement, current availability and approximate price.
3. Mark the **load-bearing** ones: the claims the story turns on, anything surprising, anything
   that would be embarrassing if wrong. Those get two independent sources.
4. Set a budget: roughly 40 to 80 searches for a full deck. Spend most of it on the load-bearing
   claims and the bottles; stop chasing colour that the story does not need.

Use the WebSearch tool (load it with ToolSearch, `select:WebSearch`) to find things, then
open and read them with `curl` (browser User-Agent, `python3 -I` to strip the HTML) or
WebFetch. Search with specific words: names, years, exact product names, statute numbers.
Archives with their own search (newspapers, Internet Archive, SEC, eCFR) are searched
directly; see the recipes file.

### Sources, best first

1. **Primary documents and official bodies**: contemporary newspapers (the Library of
   Congress's Chronicling America collection, newspapers on the Internet Archive, state
   archives such as Hoosier State Chronicles); county and local histories (the
   nineteenth-century "History of X County" books are on the Internet Archive in full text);
   old trade journals (also on the Internet Archive); statutes and regulations (eCFR, the
   Federal Register); the TTB, its rulings and its public COLA label registry; SEC filings
   (EDGAR full-text search) for anything a public company did; court records and settlements;
   state and county historical societies; the Scotch Whisky Association, Japan's spirits
   makers' standard.
2. **Named historians and established whisky writers**: books, journal articles and long-form
   pieces (Chuck Cowdery's blog and books, Whisky Advocate, Punch, VinePair, Bourbon & Banter,
   Fred Minnick, Breaking Bourbon, enthusiast researchers who cite their documents). Good for
   interviews with distillers, which are often the only record of how a recipe came about.
3. **The maker's own statements**: good for what a bottle is (proof, recipe, age) and for what
   the company says about itself, weak for its history and legends. Cite them as the maker's
   claim ("the company's timeline says").
4. Reference works. Wikipedia is a map to its citations: open its raw wikitext to see them,
   follow them, cite what you reach. A Wikipedia sentence with no citation is a lead, not a fact.
5. A blog or a retailer page alone is not enough for anything that matters. Retailer listings
   are fine for current shelf prices, dated.

**Paywalled or unreachable material** (JSTOR, Newspapers.com, Ancestry, most books from the
last ninety years, library-lending-only scans): do not cite what you cannot read. Name it in
the outline as **not read**, say why it matters, and list it under **Worth getting** so the
owner can supply scans or a library copy.

The owner's own outline on why: "Chase the primary sources. Cocktail history is unusually
infested with blog posts citing blog posts, and the underlying documents are almost all
digitized and sitting there for free."

### When a page cannot be fetched

Some sites refuse automated clients or rate-limit them. Try, in order: a browser
User-Agent; a pause and one retry; the Wayback Machine
(`https://web.archive.org/web/2026/<url>`); the same document from another host (a press
release on PR Newswire as well as the company site; a filing on sec.gov as well as the
company's investor pages); the same fact from a second publisher. The recipes file lists
which sites refused in practice.

If, after that, a claim rests only on a search snippet, it is **not read**: it goes in **Not
confirmed**, or is said aloud as "one account says". Never cite a document you have not
seen, and never write "read" for a source you saw only in a search result.

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
10. **Worth getting**: sources that would settle an open question or deepen the story but
    could not be read (paywalled, lending-only, not digitised), each with what it would
    answer, so the owner can supply a scan.
11. **Sources**: everything cited, title, author or publisher, date, URL, and how far it was
    read (read in full / read in part, which part / not read).
12. **Image credits**, last: per slide, the title, author or institution, licence, where it was
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

- Every fact in the script and on the slides is in "What's established" or explicitly hedged,
  and each established fact rests on a source marked read in full or read in part.
- "Not confirmed" is honest and complete; nothing in it appears on a slide as fact.
- No Jameson bottle anywhere; no song lyrics; every image credited with its licence.
- Prices and availability carry a date.
- Hand back a short list: corrections you made to the story as first imagined, the load-bearing
  facts and their sources, and what stays unconfirmed.
