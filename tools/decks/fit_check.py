"""Flag text that will wrap further in Keynote than in the previews and run into what is below it.

    python3 -I tools/decks/fit_check.py deck.pptx [deck.pptx ...]

The slide PNGs are rendered with open fonts (Nunito Sans, Gelasio) standing in for the
Keynote fonts (Avenir Next, Georgia). Avenir Next sets wider, so a heading that fits one
line in a PNG can take two in Keynote and print over the text under it. That happened on
Cardhu slide 11. This estimates each text box's height at Keynote widths and reports a box
that takes more lines in Keynote than in the preview, passes its own bottom edge and
reaches another text box or picture.

It wraps each paragraph word by word with the preview fonts' own metrics, once as the
preview does and once 8% wider for Avenir Next (measured about 5% from a Keynote
screenshot). A report means: this text takes an extra line in Keynote and lands on
something. Fix it by shortening the text or giving it room, not by trusting the PNG.
"""
import os, subprocess, sys
from PIL import ImageFont
from pptx import Presentation

E = 914400
KIT = os.path.dirname(os.path.abspath(__file__))
# Keynote's Avenir Next sets about 5% wider than the preview's Nunito Sans (measured from a
# Keynote screenshot of Cardhu slide 11 against the same line here). 8% leaves a margin.
# Georgia and Gelasio are metric-compatible; 2% covers rounding.
WIDER = {'sans': 1.08, 'serif': 1.02}
_fonts = {}

def _serif_file(italic):
    pattern = 'Gelasio:italic' if italic else 'Gelasio:roman'
    out = subprocess.run(['fc-match', '-f', '%{file}', pattern], capture_output=True, text=True,
                         env={**os.environ, 'FONTCONFIG_FILE': os.path.join(KIT, 'fonts', 'fonts.conf')}).stdout
    return out or None

def font_for(name, bold, italic):
    sans = bool(name) and ('Avenir' in name or 'Nunito' in name)
    key = (sans, bool(bold), bool(italic))
    if key not in _fonts:
        path = os.path.join(KIT, 'fonts', 'NunitoSans-Italic.ttf' if italic else 'NunitoSans.ttf') if sans \
            else _serif_file(italic)
        f = ImageFont.truetype(path, 1000)
        try:
            axes = f.get_variation_axes()
            f.set_variation_by_axes([(700 if bold else 400) if b'eight' in (a['name'] if isinstance(a['name'], bytes)
                                     else a['name'].encode()) else a['default'] for a in axes])
        except Exception:
            pass
        _fonts[key] = f
    return _fonts[key], ('sans' if sans else 'serif')

def lines_and_height(shape, keynote):
    """(height in inches, number of lines) with real word wrapping, at preview or Keynote widths."""
    tf = shape.text_frame
    width = (shape.width - tf.margin_left - tf.margin_right) / E
    total, count = 0.0, 0
    for p in tf.paragraphs:
        runs = [r for r in p.runs if r.text]
        if not runs:
            continue
        size = max((r.font.size.pt if r.font.size else 18) for r in runs)
        words = []                                   # (text, width in inches) per word, across runs
        for r in runs:
            f, kind = font_for(r.font.name, r.font.bold, r.font.italic)
            pt = r.font.size.pt if r.font.size else size
            k = pt / 72 / 1000 * (WIDER[kind] if keynote else 1.0)
            space = f.getlength(' ') * k
            for line in r.text.split('\v'):
                for w in line.split(' '):
                    words.append((f.getlength(w) * k, space))
        lines, x = 1, 0.0
        for w, space in words:
            if x and x + space + w > width:
                lines, x = lines + 1, w
            else:
                x = x + (space if x else 0) + w
        ls = p.line_spacing if isinstance(p.line_spacing, float) else 1.2
        after = p.space_after.pt / 72 if p.space_after else 0
        total += lines * size / 72 * 1.2 * ls + after
        count += lines
    return total + (tf.margin_top + tf.margin_bottom) / E, count

def overlaps(path):
    """The list of possible Keynote overlaps in one .pptx, as sentences."""
    found = []
    prs = Presentation(str(path))
    for n, slide in enumerate(prs.slides, 1):
        boxes = [s for s in slide.shapes if (s.has_text_frame and s.text_frame.text.strip()) or s.shape_type == 13]
        for s in boxes:
            if not (s.has_text_frame and s.text_frame.text.strip()):
                continue
            top, left, right = s.top / E, s.left / E, (s.left + s.width) / E
            box_bottom = (s.top + s.height) / E
            need, lines = lines_and_height(s, keynote=True)
            if lines <= lines_and_height(s, keynote=False)[1]:
                continue        # wraps the same in both: the PNG already shows it
            anchor = s.text_frame.vertical_anchor
            if anchor is not None and int(anchor) != 1:      # middle or bottom anchored
                if need <= s.height / E + 0.05:
                    continue
                text_bottom = box_bottom + (need - s.height / E) / 2
            else:
                text_bottom = top + need
            if text_bottom <= box_bottom + 0.02:
                continue
            for o in boxes:
                if o is s:
                    continue
                otop, oleft, oright = o.top / E, o.left / E, (o.left + o.width) / E
                if top + 0.05 <= otop < text_bottom - 0.03 and oleft < right and oright > left:
                    what = o.text_frame.text.strip()[:40] if o.has_text_frame else 'a picture'
                    found.append('slide %d: "%s" takes an extra line in Keynote and reaches "%s"'
                                 % (n, s.text_frame.text.strip()[:50].replace('\n', ' '), what.replace('\n', ' ')))
                    break
    return found


def main(paths):
    bad = 0
    for path in paths:
        for line in overlaps(path):
            print('%s %s' % (os.path.basename(path), line))
            bad += 1
    print('%d possible overlaps' % bad)
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
