"""Build a WSS deck package from its sources, then check it.

    python3 -I tools/decks/build.py <source_dir> <out_root>

<source_dir> holds the sources (the markdown is the source of truth):
    deck.json            slug, title, subtitle, category, difficulty, duration, description, tags, pours
    speaker-notes.md     the script, one "## [SLIDE n] Title" section per slide
    research-outline.md  the outline
    slides.py            the slides, drawn with wsskit (from wsskit import *)
    assets/              the deck's own images (credited in the outline)

<out_root>/<slug>/ becomes a complete package that `bin/rails decks:load` accepts:
    deck.json, speaker-notes.md, research-outline.md, assets/,
    <slug>.pptx, <slug>-speaker-notes.pdf, <slug>-research-outline.pdf, slides/slide-NN.png

Then it checks: one [SLIDE n] per slide, every notes field filled, one PNG per slide,
the script split by a single '---' rule. Look at every PNG yourself afterwards; a passing
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
import wsskit  # noqa: E402

REQUIRED = ['deck.json', 'speaker-notes.md', 'research-outline.md', 'slides.py']
META_KEYS = ['slug', 'title', 'subtitle', 'category', 'difficulty', 'duration', 'description', 'tags', 'pours']


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
    for name in [slug + '-speaker-notes.pdf', slug + '-research-outline.pdf']:
        if not (out / name).is_file():
            problems.append('missing ' + name)
    if problems:
        fail('checks failed:\n  - ' + '\n  - '.join(problems))
    print('checks passed: %d slides, %d notes sections, %d PNGs, both PDFs. Now look at every slide.'
          % (n, n, len(pngs)))
    print('package ready: %s' % out)


if __name__ == '__main__':
    main()
