# The WSS notes and outline markdown dialect

`speaker-notes.md` and `research-outline.md` are the source of truth. Three programs read
them, and each understands only what is listed here:

- `tools/decks/pdfs.py` turns both into the branded PDFs;
- `tools/decks/wsskit.py` (`load_notes`, `to_plain`) puts each `[SLIDE n]` section into
  slide n's notes field in the pptx;
- `app/services/deck_package_import.rb` (`DeckPackageImport#story`) turns the script into
  the story readers see on the deck page.

Anything else (tables, numbered lists, links, `*single-star italics*`, nested bullets,
images, HTML) prints literally or loses its formatting. Keep to the list.

## Line by line

| Write | You get in the PDF | Notes |
|---|---|---|
| `# Deck title` (first line) | The title under the header band | One `#` heading per file, at the top. |
| Plain lines right after the `#` title, before anything starting `#`, `>`, `_` or `-` | The cover block: first line italic, second roman | Notes: `Speaker's notes` then `The Whiskey Share Society`. Outline: `Research outline: <subtitle>`. Only the first two are shown. |
| `## Heading` | Section heading (Oswald, green) | Starts a new page if less than about 1.8 in remains. |
| `## [SLIDE n] Title` | Small `SLIDE n` label over the title | Notes only. One per slide, numbered 1..N with no gaps or repeats; N = slides in the deck. `build.py` refuses a mismatch. |
| `## Module n. Title` | Small `MODULE n` label over the title | Outline only. |
| `### Subheading` | Small caps subheading | e.g. `### What's established`, `### Bottle ideas by role`. |
| A paragraph | Body text | Lines of one paragraph may wrap; a blank line ends it. |
| `_A whole paragraph between underscores._` | Green italic stage direction | Notes field shows it as `[CUE] ...`. The whole paragraph must be wrapped, start to end. |
| `**bold**`, `_italic_` inside a paragraph | Bold, italic | Underscore italics only. `` `code` `` loses its backticks. |
| `- item` | Bullet | Continue a long item on the next line indented two spaces. |
| `- › _Source title, publisher, date: what it gives you._` | Source line with a `›` marker, italic, muted | Outline's "Go to the source" and "The short shelf". |
| `> **LABEL**` then more `>` lines | Callout box: tinted, orange left rule, label in caps | First line is the label; each later `>` line is its own paragraph. Notes field shows `[LABEL] text`. Keep a blank line before and after. |
| `---` on its own line | Notes: page break. Outline: nothing (a visual separator in the source) | See the next section: in the notes it is load-bearing. |

## The `---` rule in speaker-notes.md

Use **exactly one** `---` in `speaker-notes.md`, between Part One (before the night) and Part
Two (the script). `DeckPackageImport` keeps only what comes after the first `---` as the deck
page's story, and turns `## [SLIDE 4] Title` into `## Title`. So:

- Part One (casting, bottle ideas, prices, running order) stays off the public page.
- A second `---` inside Part One would push the casting notes onto the deck page; a `---`
  inside the script would split nothing but make a stray page break. `build.py` fails if there
  is not exactly one.
- The first 24 source lines after the rule are the **public teaser** on the deck page (anyone
  can read them; the rest is for owners). Open the script with the `## Part Two: the script`
  heading, the short SET UP direction and slides 1 and 2: the welcome and the hook. Never put
  the reveal there.

The outline has no such rule; `---` between modules there is decoration.

## Skeletons

Speaker notes:

```markdown
# Deck Title

Speaker's notes

The Whiskey Share Society

_READ THIS FIRST. The one thing to know before opening the box._

## Part One: before the night

### The one-sentence version

One sentence: the story in brief.

### Cast the roles, then find the bottles

- **The Role (glass 1).** What its job is. Tonight: Bottle Name.

### Bottle ideas by role

Suggestions, not instructions. Prices are rough US shelf prices checked in <month year>.

**The Role**

- **Bottle Name.** About $NN. NN proof. One true line about it.

> **RUNNING ORDER: ABOUT 45 MINUTES**
> 0–15 min: ... slides 1–5.
> 15–30 min: ... slides 6–10.

---

## Part Two: the script

_SET UP: glasses, what is poured before slide 1, what stays hidden._

## [SLIDE 1] Deck Title

Good evening.

## [SLIDE 2] Slide title

_Pour glass 1 now. Keep talking while you pour._

Read-aloud text.

> **DO NOT OVERSELL IT**
> What the host must not claim, and why.

## [SLIDE N] Sláinte

Closing words.

Sláinte.
```

Research outline:

```markdown
# Deck Title

Research outline: subtitle

_This is the other half of the speaker notes. It does not tell you what to say; it tells you where to look..._

> **THE SPINE OF THE STORY**
> A → B → C, with dates.

## How to use this

...

---

## Module 1. Title

_The question worth answering?_

### What's established

- **1847.** A dated, sourced fact.

### Go to the source

- › _Author, "Title", publisher, date: what it gives you._

### Threads worth pulling

- An open question someone could chase.

> **TRAPS**
> The claim that trips people up, and what is actually true.

## Claims that don't hold up
## The short shelf
## Not confirmed
## Sources
## Image credits
```

## Check before building

- `grep -c '^## \[SLIDE' speaker-notes.md` equals the number of slides.
- `grep -c '^---$' speaker-notes.md` is 1.
- No `*italic*`, tables or numbered lists (`grep -nE '^\s*[0-9]+\. |^\|' *.md`).
- Every stage direction is a whole paragraph in underscores, not a sentence inside one.
