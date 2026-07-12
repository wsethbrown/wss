# WSS scorecard generator (offline tool)

This produced the **blank tasting scorecard** shipped at
`app/assets/documents/wss_scorecard_blank.pdf`, which every deck's downloads
include as a fallback (see `Presentations::DownloadsController#blank_scorecard`).

**It is NOT wired into the Rails app.** It's kept here so the blank template is
reproducible if the design ever needs editing — regenerate the PDF and copy it
over the shipped asset.

## Regenerate the blank

Needs Python 3, `reportlab`, and the Crimson Text TTFs. The script looks for the
fonts in a sibling `fonts/` directory relative to its parent
(`script/fonts/CrimsonText-{Regular,Bold,Italic,SemiBold}.ttf`). Drop the four
TTFs there first (they're not committed — grab them from Google Fonts:
https://fonts.google.com/specimen/Crimson+Text).

```sh
pip install reportlab
# place CrimsonText-*.ttf under script/fonts/
python3 script/scorecard/wss_scorecard.py --blank /tmp/blank.pdf 6 1
cp /tmp/blank.pdf app/assets/documents/wss_scorecard_blank.pdf
```

Args: `--blank <out.pdf> [samples] [copies]`. The shipped asset uses the default
`BLANK` config (6 sample rows A–F, one page).

To generate a deck-specific card, write a `config.py` defining `CONFIG` (a dict
shaped like `BLANK`) and optional `COPIES`, then:
`python3 wss_scorecard.py config.py out.pdf`.
