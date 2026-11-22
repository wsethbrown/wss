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

`subtitle` (required by `build.py`) is customer copy: the site shows it under the title on the
deck page, so its wording is approved with the deck. Up to 140 characters (`check_meta`).

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
| `repair_pptx.py` | Writes a Keynote-openable copy of a pptx built before the notes-master fix; `--check` only reports. Standard library only. |
| `tests/test_keynote.py` | Checks the pptx structure Keynote needs (no Keynote required). |
| `inspect_pptx.py` | Dump shapes, positions, fonts and notes of any pptx (for studying reference decks). |
| `assets/` | The WSS logo, cream (for green grounds) and green (for paper). |
| `examples/the-rye-from-lawrenceburg/` | The pilot package's sources: a worked example, not a template. |

## Keynote

Keynote refuses a pptx ("The file format is invalid") when the package has a notes master
that `ppt/presentation.xml` does not list in `<p:notesMasterIdLst>`. python-pptx leaves that
element out whenever a slide has notes, and every deck here has notes on every slide.
PowerPoint, Google Slides and LibreOffice open such a file anyway, so only Keynote (and macOS
Quick Look, which hangs on it) shows the fault. `wsskit.finish` now writes the element
(`link_notes_master`) and `build.py`'s checks fail if it is missing or misplaced. It names a
part and draws nothing, so slide images are unchanged.

Confirmed in Keynote on 22 November 2026: the four decks in `sources/`, rebuilt, open with
their slides and speaker notes; a bare python-pptx deck with notes and without the element is
refused. A repaired deck from the older picture-per-slide builder also opens, although its
slide size still carries the stale `type="screen4x3"` label, so that label does not stop
Keynote.

```bash
python3 -I -m unittest discover -s tools/decks/tests -t tools/decks/tests -v   # needs python-pptx, lxml
python3 -I tools/decks/repair_pptx.py --check some.pptx                        # ok, or what is wrong
python3 -I tools/decks/repair_pptx.py old.pptx repaired.pptx                   # a fixed copy; never overwrites
```

A deck built before this fix can be rebuilt from its sources, or repaired with
`repair_pptx.py`, which adds the one element and copies every other part byte for byte.
It refuses an output path that already exists, writes nothing when it fails or when the deck
has no notes master, and answers a file it cannot read with one line and a non-zero exit.
A quick check on a Mac without opening Keynote: `qlmanage -t -o <dir> <file>.pptx` writes a
thumbnail for a good file and hangs on a faulty one. A deck that any other tool re-saves
(or any pptx made with python-pptx elsewhere) needs the same check.

## A new deck

```bash
cp -r tools/decks/examples/the-rye-from-lawrenceburg ~/decks-src/my-deck   # then rewrite every file
```

Keep the sources somewhere durable, never only in a scratch directory a session can lose.
Where finished decks' sources live is the owner's call; a folder in this repo such as
`tools/decks/sources/<slug>/` (text and small assets only) is one option.
