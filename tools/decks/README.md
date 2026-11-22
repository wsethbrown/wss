# Deck build tools

Builds a Whiskey Share Society tasting-night package (deck, speaker notes, research
outline, slide images) from markdown and a short Python slide file, ready for
`bin/rails decks:load`. How to write a deck is in the skills, not here:
`.claude/skills/wss-deck-creation` (start there), `wss-deck-outline`, `wss-deck-speaker-notes`.

These run outside the Rails app and outside Docker; nothing here is loaded by the app.

## Install (once)

```bash
pip install python-pptx reportlab pillow lxml   # add --break-system-packages on a system Python
# LibreOffice (soffice) and poppler (pdftoppm), for the slide images:
sudo apt-get install -y libreoffice-impress poppler-utils   # macOS: brew install --cask libreoffice; brew install poppler
```

Fonts ship here (`fonts/`, SIL Open Font License, licence texts beside them) and in
`docker/fonts/` (Gelasio). Nothing needs installing system-wide: `render.sh` points
LibreOffice at `fonts/fonts.conf`, which substitutes Nunito Sans for Avenir Next and
Gelasio for Georgia, and `pdfs.py` loads Oswald and Crimson Text from `fonts/` directly.

## Build

```bash
python3 -I tools/decks/build.py <source_dir> <out_root>
```

For example, the pilot deck:

```bash
python3 -I tools/decks/build.py tools/decks/examples/the-rye-from-lawrenceburg tmp/decks
```

writes `tmp/decks/The-Rye-From-Lawrenceburg/` with the pptx (script in every notes field),
both PDFs, `slides/slide-NN.png` and copies of the sources, then checks the counts match.
Then load it as a draft: `bin/rails decks:load DIR=tmp/decks` (see `wss-deck-pipeline`).

`deck.json` may also carry `takeaways` (`[{"title", "text"}]`, the deck page's "What you'll
learn") and `sections` (`[{"heading", "lines": [...]}]`, its extra sections; a line
`"Label: text"` is a labelled row). Both are optional and copied into the package as they are;
`build.py` checks their shape and the site's limits first (`check_meta`) and fails before
building. Leaving one out means a re-upload keeps what the admin typed; an empty list clears it.
Their wording is customer copy, drafted with the description and approved by the owner (see
`wss-deck-creation`).

Build into the repo's `tmp/decks` (gitignored, and visible inside the Docker containers) or a
folder outside the repo. Built files (pptx, PDFs, PNGs) are never committed.

## Files

| File | What it does |
|---|---|
| `build.py` | The one command: pptx, both PDFs, slide PNGs, then the checks. |
| `wsskit.py` | Slide helpers a deck's `slides.py` imports: site palette, text, cards, photos, footer, title / Sláinte / glass slide layouts, notes loader. |
| `pdfs.py` | `speaker-notes.md` and `research-outline.md` to branded PDFs (reportlab). |
| `render.sh` | pptx to `slides/slide-NN.png`, 1600 px wide, through LibreOffice. |
| `duotone.py` | Crop a photo to its frame's ratio; optionally print it in green and cream. |
| `commons_search.py` | Search Wikimedia Commons and print a file's licence, author and date. |
| `inspect_pptx.py` | Dump shapes, positions, fonts and notes of any pptx (for studying reference decks). |
| `assets/` | The WSS logo, cream (for green grounds) and green (for paper). |
| `examples/the-rye-from-lawrenceburg/` | The pilot package's sources: a worked example, not a template. |

## A new deck

```bash
cp -r tools/decks/examples/the-rye-from-lawrenceburg ~/decks-src/my-deck   # then rewrite every file
```

Keep the sources somewhere durable, never only in a scratch directory a session can lose.
Where finished decks' sources live is the owner's call; a folder in this repo such as
`tools/decks/sources/<slug>/` (text and small assets only) is one option.
