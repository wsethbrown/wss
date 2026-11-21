# WSS deck house style

Written in November 2026 from the owner's three reference packages ("A Story Someone Else
Wrote" / Value vs Prestige, "Whisky From Japan", "Mint Julep, Cocktails Chapter One") and the
owner's own `wss-presentation` skill (synced to the owner's account, not in this repo). The owner
has said those three decks are **a small sample of many styles the site can and will use**, that
the old dark-brown / cream / burnt-orange look is not required, and that "these 'rules' I'm
giving you about deck creation aren't hard and fast. There are always exceptions to the rules."

So this file has three parts:

1. **Package defaults**: what a WSS package normally does, whatever it looks like. A few lines
   are true hard lines (marked **Hard line**); everything else is a default with a reason, to be
   broken when the story is better for it.
2. **Free choices**: how the three reference decks happened to do it, measured, so a new deck can
   borrow from them or knowingly depart from them.
3. **The pilot's choices**: The Rye From Lawrenceburg, the first deck built with `tools/decks/`.

---

## Part 1. Package defaults (and the few hard lines)

### The package

Three artifacts that stay in sync, with the markdown as the source of truth:

| Artifact | Format | Reader |
|---|---|---|
| Deck | `.pptx`, 16:9 (13.333 × 7.5 in), opens in Keynote and PowerPoint | the room |
| Speaker notes | `speaker-notes.md` → branded PDF | the host, read aloud |
| Research outline | `research-outline.md` → branded PDF | anyone rebuilding the night |

For the site, also: `deck.json` (slug, title, subtitle, category, difficulty, duration,
description, tags as a comma string, pours `[{name, origin, style, strength, notes}]`) and
`slides/slide-NN.png` rendered from the pptx at 1600 px wide.

### The deck

- **Slide 1 is the title slide**: WSS logo, the theme name, and a one-sentence hook.
- **The last slide is Sláinte**, with the logo back. Nothing after it: no sources, no appendix,
  no "questions?". (Value vs Prestige folds The Point and Sláinte into one closing slide; Japan and
  Mint Julep give Sláinte its own slide. Either is fine as long as Sláinte is last.)
- One idea per slide. Real, editable text (not full-slide pictures of text).
- **Hard line.** **The whole script is pasted into each slide's notes field**, so presenter view works without
  the PDF. `[SLIDE n]` in the notes = slide n in the deck, always. Insert a slide → renumber.
- **No notes-to-self on slides.** Nothing that talks to the author ("retitle this", "cited
  everywhere as the first; it is the fifth"). Corrections live in the notes or outline.
- **Hard line.** Images are attributed (in the outline's image credits). Public-domain (for example
  pre-1929), freely licensed (CC0, CC BY, CC BY-SA, credited as the licence asks) or owner-supplied
  images only; no manufacturer press photos, no copyrighted maps. Where no free image exists, leave a
  clean placeholder and list it.
- **Hard line.** No song lyrics, ever. Poems only as short public-domain excerpts with citation.
- **Hard line.** No Jameson. The owner: "Take jameson out of the presentations. Hate that brand."
  No Jameson bottle is poured or suggested as a swap; the firm is named only where a history
  cannot be told without it.

### The story (owner's rule, November 2026)

- **Narrative first.** In the owner's words: "tell an INTERESTING story about whiskey and present
  bottles that reflect and/or are directly related to that story." Decks are not arguments,
  gotchas or exposés. A one-sentence summary still helps (the Mint Julep notes open with "The
  one-sentence version"), but it is the story in brief, not a thesis to prove.
- **Bottles belong to the story.** Each pour is introduced where it sits in the narrative and has
  a role in it. A blind element is optional, used only when it adds fun; no reveal table as a
  verdict.
- **Warm and fair.** Respect what brands and people did. "If you sneer at it, your audience stops
  trusting you." Hard chapters (a lawsuit, a myth) are told plainly, not as a charge sheet.
- Audience: enthusiasts who know the basics. Do not explain what a barrel does; do explain the
  thing the story turns on.
- Slide 1 carries an engaging hook; the Sláinte slide carries a closing thought, not a ruling.

### Truth standard

- **Hard line.** Every factual claim traces to a source listed in the outline, found by research
  done for this deck, not recalled from memory. Nothing is invented: no facts, quotes, prices,
  tasting results or people.
- **Say out loud what cannot be proved**: "the story goes…", in the script. The outline's
  standard of proof: "If a claim can't be traced past a blog post, it goes on the slide as 'the
  story goes…' and not as a fact. It costs you nothing to say so, and it makes everything else you
  say more believable."
- Prices are approximate US shelf prices, labelled as such, with the date checked. ("Say which
  price you're using, shelf, secondary, or what you actually paid.")
- People are not props: the powerful's version of a story is usually the one recorded. Say so.

### Speaker notes (a stable structure; the wording is the host's)

1. Title block: deck title, "Speaker's notes", the Society.
2. **A READ THIS FIRST line** in green italic (the one thing to know before opening the box).
   Value vs Prestige: "The bottles in the deck are an example, not a prescription. Swap in whatever
   you can actually get." Japan: "POUR THE 10 YEAR EARLY…"
3. **Part One: Before the night.** How many bottles and why; **cast the roles first, then find the
   bottles**; **bottle ideas by role** (swap-ins, with rough prices, "Buy what you can actually
   find"); how to order them; how to match the deck to your lineup. Mint Julep adds a **running
   order** box (minutes → slides) and **The one-sentence version**.
4. **Part Two: The script.** A short green-italic STRUCTURE / SET UP block, then one section per
   slide: `SLIDE n` (small orange label), the slide title (heading), roman text to read aloud.
5. **Stage directions** are separate lines in green italic ("Pour Glass A now. Don't say what's
   in it yet.").
6. **Callout boxes**: tinted box, orange left rule, small caps orange label, short body. Used for
   optional asides and host warnings: THE ONE RULE, BEFORE YOU ADVANCE, DO NOT OVERSELL IT, SAY THE
   CAVEAT OUT LOUD, THE KIND TRAP. NAME IT GENTLY. Labels are imperative and specific.
7. Reveal sections follow a repeatable beat: name it → one true fact → why it sat where it sat →
   one question, then stop talking.

### Research outline (a stable structure)

- Addressed to **anyone rebuilding the talk**, never to "the presenter". Never "your deck",
  "fix this before you present", never tells the reader what to conclude, never snipes at other
  writers.
- Opening: what this document is ("This is the other half of the speaker notes. It doesn't tell
  you what to say — it tells you where to look…"), then **The spine of the story** (or **The
  argument**) in a callout.
- **Modules**, each with: the question worth answering (green italic under the heading),
  **What's established** (facts with dates), **Go to the source** (› bulleted, italic, free and
  online first), **Threads worth pulling**, and a **Traps** callout.
- Then: **Claims that don't hold up**, **The short shelf** (five things to read), **Not confirmed**,
  sources, image credits.

### PDF template (both documents)

- US Letter, 58 pt side margins (0.8 in).
- Page 1: a dark header band full width, 108 pt tall, with the logo at left (about 1.1 in), a
  small orange series line (Oswald 9 pt, tracked caps) and the document title (Oswald 25 pt,
  cream `#F2EAD9`), optionally an italic subtitle (Crimson Text italic 11 pt, `#B9A88E`). A 2.2 pt
  orange rule (`#C0692A`) closes the band.
- Following pages: running head (document title left in Oswald 8.8 pt caps, mute; "The Whiskey
  Share Society" right in Crimson italic, orange) over a 0.6 pt hairline (`#C9B893`).
- Footer: hairline, then "The Whiskey Share Society · <series> · <deck title>" in Crimson italic
  8.6 pt mute, page number right in Oswald orange.
- Page ground cream `#FAF5EA`; text `#2B2018`; mute `#6A5A48`; stage directions green
  `#5F7A4C`; callout fill `#F0DCC0` with a 2.2 pt orange left rule.
- Type: Oswald (headings, labels), Crimson Text (body 12.2 pt; bullets 10.6 pt; callouts 10.2 pt).
- **Template bugs in the owner's files, not to copy:** every reference PDF says "UNTITLED" in the
  header and "Cocktails, Chapter One · Mint Julep" in the footer, even the Japan and Value vs
  Prestige documents. Ours show the real deck title and series on every page.

---

## Part 2. Free choices (how the reference decks did it)

The three decks are three different looks. A new deck may borrow, mix or replace them, provided
it sits comfortably with the site brand (WSS logo; site paper `#f6f4ee`, bottle green `#16332a`,
logo orange `#ff6d00` as a small mark only; no yellow or amber, no gradients, no glass).

### Three deck formats and their running order

**A. Blind-tasting argument — Value vs Prestige (12 slides).**
1 Title · 2 The Premise · 3 Tips on tasting (stays up for the whole pour sequence) · 4–9 one
reveal slide per sample, A–F · 10 One thing to notice (the same-distillery pair) · 11 The reveal
(table: bottle, proof, price, room score, room rank) · 12 The Point + Sláinte.
The tasting happens off-slide, blind, on slide 3; the sample slides go up only afterwards.

**B. Category / distillery deck — Whisky From Japan (15 slides).**
Pour early, history while they drink, then the turn ("What is actually in your glass"), tasting
housekeeping, one slide per expression (10, 12, 16 year), Sláinte. History is there to set up a
single reveal about the liquid in hand.

**C. Cocktail history — Mint Julep, Cocktails Chapter One (18 slides).**
Two glasses (A then B), a chronological argument with maps and a timeline, portraits of the people
who made the drink, a head-to-head, "build it at home", Sláinte as a short prose poem.

### Measured specs of the reference looks

**Value vs Prestige** (Google Slides export, 13.333 × 7.5 in):

| Token | Hex | Use |
|---|---|---|
| Dark ground | `#3A2A1A` | title, dark sample slides, The Point |
| Cream ground | `#F6EFE2` | content slides |
| Gold | `#C28A2C` | frame line, rules and letters on dark |
| Copper | `#A9621B` | labels, rules, sample letters on cream |
| Ink | `#2B2017` | text on cream |
| Mute | `#6E5A42` | meta lines |
| Tan | `#D8C5A4` | hairlines, bottle shadow ellipse, subtitle on dark |
| Panel | `#EFE4D0` | discussion box, table bands |

- Type: Georgia (headings 33–40 pt bold, body 14.5–19 pt, title 56 pt mixing italic/regular/bold),
  Gill Sans (labels 11 pt caps, meta 12.5 pt, table heads 13 pt bold). Gill Sans is embedded.
- Grammar: label (Gill Sans 11 pt caps, copper) at y 0.70 in → heading at y 1.05 → short rule
  1.4 × 0.03 in at y ~2.0 → body at y 2.5, left margin 0.80 in.
- Sample slide: bottle photo 1.9 × 5.45 in at (1.25, 0.65) on a tan shadow ellipse; letter in
  Georgia 80 pt bold at (3.5, 0.5); name 33 pt; meta line "Distillery · Town, ST · proof · detail"
  in Gill Sans 12.5 pt; prose 4.55 in wide; white tasting box 3.25 × 3.75 in at (9.55, 2.30) with
  NOSE / TASTE / FINISH labels (Gill Sans 12 pt bold) over Georgia 12.5 pt "a · b · c" notes;
  DISCUSSION strip 7.95 × 0.85 in at y 6.05.
- Title and closing slides: a thin gold frame 0.45 in in from the edge; logo 4 × 3.16 in.

**Whisky From Japan**: warm paper `#FAF5EA` / `#F0E7D6` panels, ink `#2B2018`, orange `#C0692A`,
mute `#6A5A48`; Georgia caps headings (34 pt), orange italic subtitle line, small caps footer
"THE WHISKEY SHARE SOCIETY · WHISKY FROM JAPAN"; bottle slides with three spec boxes (mash bill,
age · proof, cask · price). Full-bleed photo collage on one slide.

**Mint Julep**: dark `#241E18` throughout, cream `#F2EAD9` headings (Georgia 40 pt bold, tracked
caps), orange `#E8913F` italic subtitles and small caps row labels, body `#B9A88E` 17 pt; a two-
column "label → text" grammar; maps and a timeline drawn as artwork.

### Tone of voice (keep this; it is the owner's)

Plain, warm, a little dry, short sentences, the host talking to friends:

- "Tonight, the label doesn't get a vote."
- "A bottle's price is a story someone else wrote."
- "Heat is not flavour. If you score heat, you are just scoring proof."
- "Write your score before you talk. The first number is the honest one. Everything after it is
  negotiated with the room."
- "If the room scored them close, that is the finding. If the room scored the expensive one higher,
  that is also the finding. Sometimes the money is real."
- "Bonded means authentic, not excellent. It is a floor, not a ceiling."
- "Years later, the only thing the future King of England could remember about Richmond was that
  julep."

Slides carry the line; the notes carry the explanation. Headings are sentences or short noun
phrases, not labels.

---

## Part 3. The pilot's choices (The Rye From Lawrenceburg)

Recorded so later decks can reuse or depart from them knowingly.

- **Palette:** site tokens. Paper `#F6F4EE` content slides; bottle green `#16332A` for the title,
  one story slide and Sláinte; raised green `#1D4034` with edge `#2F5546` for a panel on green;
  white cards with hairline `#DFE3DC`; mute `#5F6B64`; logo orange `#FF6D00` only as small marks
  on green, `#E65C00` for dots and rules on paper. No orange text on light grounds.
- **Type:** Avenir Next (headings, labels, meta) and Georgia (body, italic turning phrases), both
  standard in Keynote on a Mac. For rendering here, Avenir Next is substituted by Nunito Sans and
  Georgia by Gelasio (metric-compatible) through a fontconfig alias.
- **Grammar:** 0.85 in margins; footer "Title · The Whiskey Share Society" and a two-digit slide
  number at y 6.93 in, 10 pt mute. History slides lead with a 150 pt year. Bottle slides: photo or
  bottle-shaped placeholder card 3.4 × 5.3 in at left, "Glass n" line with an orange dot, the name at
  38 pt, a meta line (where distilled · whose hands · proof · approximate price), two short
  paragraphs, a white card of three short facts (Distilled / Their hands / Look for), and an
  "Ask the room" strip.
- **Documents:** the owner's PDF template structure (band, rule, running head, footer, callouts,
  green stage directions) in site colours, Oswald and Crimson Text, built with reportlab from the
  markdown (`tools/decks/pdfs.py`). Slide helpers in `tools/decks/wsskit.py`; the slides
  themselves in `tools/decks/examples/the-rye-from-lawrenceburg/slides.py`.
