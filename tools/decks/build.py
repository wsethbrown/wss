"""Build a WSS deck package from its sources, then check it.

    python3 -I tools/decks/build.py <source_dir> <out_root>

<source_dir> holds the sources (the markdown is the source of truth):
    deck.json            slug, title, subtitle, category, difficulty, duration, description, tags, pours,
                         and optionally takeaways and sections (checked here, see check_meta)
    speaker-notes.md     the script, one "## [SLIDE n] Title" section per slide
    research-outline.md  the outline
    slides.py            the slides, drawn with wsskit (from wsskit import *)
    assets/              the deck's own images (credited in the outline)

<out_root>/<slug>/ becomes a complete package that `bin/rails decks:load` accepts:
    deck.json, speaker-notes.md, research-outline.md, assets/,
    <slug>.pptx, <slug>-speaker-notes.pdf, <slug>-research-outline.pdf, slides/slide-NN.png

Then it checks: one [SLIDE n] per slide, every notes field filled, one PNG per slide,
the script split by a single '---' rule, the notes master listed in presentation.xml
(without that Keynote refuses the file). Look at every PNG yourself afterwards; a passing
check does not mean the slides look right.
"""
import json
import re
import runpy
import shutil
import subprocess
import sys
from pathlib import Path

KIT = Path(__file__).resolve().parent
sys.path.insert(0, str(KIT))

import pdfs  # noqa: E402
import repair_pptx  # noqa: E402
import wsskit  # noqa: E402

REQUIRED = ['deck.json', 'speaker-notes.md', 'research-outline.md', 'slides.py']
META_KEYS = ['slug', 'title', 'subtitle', 'category', 'difficulty', 'duration', 'description', 'tags', 'pours']
# Optional keys the site reads from the built deck.json (DeckPackageImport). Leave a key out
# and a re-upload keeps what the admin typed; an empty list clears it on the site.
#   takeaways  [{"title": "...", "text": "..."}]          the deck page's "What you'll learn"
#   sections   [{"heading": "...", "lines": ["...", ...]}] its extra sections; a line
#              "Label: text" shows as a labelled row
# The limits match the site's (app/models/presentation.rb, app/services/deck_package_import.rb),
# so a package the build passes is not refused on upload.
OPTIONAL_KEYS = ['takeaways', 'sections']
TAKEAWAYS_MAX, TAKEAWAY_TITLE_MAX, TAKEAWAY_TEXT_MAX = 10, 120, 400
SECTIONS_MAX, SECTION_HEADING_MAX, SECTION_LINES_MAX, SECTION_LINE_MAX = 8, 80, 12, 300
# The subtitle shows under the title on the deck page (customer copy, approved with the deck).
SUBTITLE_MAX = 140


def fail(msg):
    raise SystemExit('build.py: ' + msg)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    src = Path(sys.argv[1]).resolve()
    missing = [f for f in REQUIRED if not (src / f).is_file()]
    if missing:
        fail('%s is missing %s' % (src, ', '.join(missing)))
    meta = json.loads((src / 'deck.json').read_text())
    absent = [k for k in META_KEYS if k not in meta]
    if absent:
        fail('deck.json has no %s' % ', '.join(absent))
    problems = check_meta(meta)
    if problems:
        fail('deck.json:\n  - ' + '\n  - '.join(problems))
    slug = meta['slug']
    out = Path(sys.argv[2]).resolve() / slug
    if out == src:
        fail('build into a different folder from the sources')
    out.mkdir(parents=True, exist_ok=True)

    for name in ['deck.json', 'speaker-notes.md', 'research-outline.md']:
        shutil.copy2(src / name, out / name)
    if (src / 'assets').is_dir():
        shutil.copytree(src / 'assets', out / 'assets', dirs_exist_ok=True)

    # 1. the deck
    wsskit.init(src, meta['title'])
    runpy.run_path(str(src / 'slides.py'), run_name='__main__')
    n = wsskit.finish(src / 'speaker-notes.md', out / (slug + '.pptx'))
    print('wrote %s, %d slides' % (out / (slug + '.pptx'), n))

    # 2. the two PDFs
    pdfs.build_all(src, out)

    # 3. the slide images
    subprocess.run(['bash', str(KIT / 'render.sh'), str(out)], check=True)

    check(out, slug, n)


def check_meta(meta):
    """Problems with the subtitle, takeaways and sections, as the site would refuse them."""
    problems = []
    if 'subtitle' in meta:
        if not isinstance(meta['subtitle'], str):
            problems.append('"subtitle" must be text')
        elif len(' '.join(meta['subtitle'].split())) > SUBTITLE_MAX:
            problems.append('"subtitle" over %d characters' % SUBTITLE_MAX)
    if 'takeaways' in meta:
        takeaways = meta['takeaways']
        if not isinstance(takeaways, list):
            problems.append('"takeaways" must be a list')
            takeaways = []
        if len(takeaways) > TAKEAWAYS_MAX:
            problems.append('"takeaways" can have at most %d (there are %d)' % (TAKEAWAYS_MAX, len(takeaways)))
        for n, t in enumerate(takeaways, 1):
            if not (isinstance(t, dict) and isinstance(t.get('title'), str)
                    and isinstance(t.get('text', ''), (str, type(None)))):
                problems.append('takeaway %d needs a "title" and a "text"' % n)
                continue
            title, text = ' '.join(t['title'].split()), ' '.join((t.get('text') or '').split())
            if not title:
                problems.append('takeaway %d has no title' % n)
            if len(title) > TAKEAWAY_TITLE_MAX:
                problems.append('takeaway %d: title over %d characters' % (n, TAKEAWAY_TITLE_MAX))
            if len(text) > TAKEAWAY_TEXT_MAX:
                problems.append('takeaway %d: text over %d characters' % (n, TAKEAWAY_TEXT_MAX))
            if text[:1] in ('-', '\u2022', '*'):
                problems.append('takeaway %d: text starts with a dash, bullet or asterisk' % n)
    if 'sections' in meta:
        sections = meta['sections']
        if not isinstance(sections, list):
            problems.append('"sections" must be a list')
            sections = []
        kept = 0
        for n, sec in enumerate(sections, 1):
            if not (isinstance(sec, dict) and isinstance(sec.get('heading'), str)
                    and isinstance(sec.get('lines'), list) and all(isinstance(l, str) for l in sec['lines'])):
                problems.append('section %d needs a "heading" and a list of "lines"' % n)
                continue
            heading = ' '.join(sec['heading'].split())
            lines = [l.strip() for l in sec['lines'] if l.strip()]
            if not heading and not lines:
                continue  # an empty section is dropped by the site
            kept += 1
            if not heading:
                problems.append('section %d has no heading' % n)
            if len(heading) > SECTION_HEADING_MAX:
                problems.append('section %d: heading over %d characters' % (n, SECTION_HEADING_MAX))
            if not lines:
                problems.append('section %d has no lines' % n)
            if len(lines) > SECTION_LINES_MAX:
                problems.append('section %d: more than %d lines' % (n, SECTION_LINES_MAX))
            for i, line in enumerate(lines, 1):
                if len(line) > SECTION_LINE_MAX:
                    problems.append('section %d, line %d: over %d characters' % (n, i, SECTION_LINE_MAX))
        if kept > SECTIONS_MAX:
            problems.append('"sections" can have at most %d (there are %d)' % (SECTIONS_MAX, kept))
    return problems


def check(out, slug, n):
    problems = []
    notes_md = (out / 'speaker-notes.md').read_text()
    rules = re.findall(r'^---\s*$', notes_md, flags=re.M)
    if len(rules) != 1:
        problems.append("speaker-notes.md should have exactly one '---' rule (before the script); it has %d"
                        % len(rules))
    pngs = sorted((out / 'slides').glob('slide-*.png'))
    if len(pngs) != n:
        problems.append('%d slides in the pptx but %d PNGs rendered' % (n, len(pngs)))
    from pptx import Presentation
    prs = Presentation(str(out / (slug + '.pptx')))
    for i, s in enumerate(prs.slides, 1):
        txt = s.notes_slide.notes_text_frame.text if s.has_notes_slide else ''
        if not txt.startswith('[SLIDE %d]' % i) or len(txt) < 40:
            problems.append('slide %d has an empty or misnumbered notes field' % i)
    try:
        problem = repair_pptx.notes_master_problem(out / (slug + '.pptx'))
        if problem:
            problems.append(problem + ' (Keynote refuses the file)')
    except repair_pptx.UNREADABLE as e:
        problems.append('could not read the pptx to check its notes master: ' + repair_pptx.explain(e))
    for name in [slug + '-speaker-notes.pdf', slug + '-research-outline.pdf']:
        if not (out / name).is_file():
            problems.append('missing ' + name)
    try:
        import fit_check
        for line in fit_check.overlaps(out / (slug + '.pptx')):
            problems.append(line + ' (fit_check.py: shorten the text or give it room)')
    except Exception as e:          # the check must never hide a built deck behind its own failure
        print('fit check could not run: %s: %s' % (type(e).__name__, e))
    if problems:
        fail('checks failed:\n  - ' + '\n  - '.join(problems))
    print('checks passed: %d slides, %d notes sections, %d PNGs, both PDFs. Now look at every slide.'
          % (n, n, len(pngs)))
    print('package ready: %s' % out)


if __name__ == '__main__':
    main()
