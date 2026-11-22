"""Shared building blocks for WSS tasting-night decks (python-pptx, 16:9).

A deck's own `slides.py` does `from wsskit import *` and draws its slides with
these helpers; `build.py` sets up the kit, runs that file, then pastes the
script from speaker-notes.md into every slide's notes field and saves.

Everything here is a default, not a rule: a deck may define its own helpers
or palette in its slides.py when its story wants a different look.
Measurements are inches on a 13.333 x 7.5 in slide.
"""
import re
from pathlib import Path

from lxml import etree
from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_CONNECTOR, MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.oxml.ns import qn
from pptx.util import Inches, Pt

__all__ = [
    'PAPER', 'INK', 'OAK', 'OAK_EDGE', 'HAIR', 'MUTE', 'CREAM', 'CREAM_MUTE', 'MARK', 'MARK_DEEP', 'WHITE',
    'W100', 'W200', 'SANS', 'SERIF', 'SLIDE_W', 'SLIDE_H', 'PP_ALIGN', 'MSO_ANCHOR', 'MSO_SHAPE',
    'A', 'KIT', 'LOGO_CREAM', 'LOGO_GREEN', 'LOGO_RATIO', 'TITLE',
    'new_slide', 'bg', 'rect', 'rrect', 'text', 'picture', 'line', 'dot', 'footer', 'heading',
    'bottle_placeholder', 'title_slide', 'slainte_slide', 'glass_slide',
]

# The site palette (docs/redesign/DESIGN_SYSTEM.md). Orange is a mark, never text on a light ground.
PAPER = 'F6F4EE'; INK = '16332A'; OAK = '1D4034'; OAK_EDGE = '2F5546'
HAIR = 'DFE3DC'; MUTE = '5F6B64'; CREAM = 'F6F4EE'; CREAM_MUTE = 'B9C6BE'
MARK = 'FF6D00'; MARK_DEEP = 'E65C00'; WHITE = 'FFFFFF'; W100 = 'ECEBE3'; W200 = 'DEDCCF'
# Standard in Keynote on a Mac; render.sh substitutes Nunito Sans and Gelasio for them.
SANS = 'Avenir Next'; SERIF = 'Georgia'
SLIDE_W, SLIDE_H = 13.333, 7.5

KIT = Path(__file__).resolve().parent
LOGO_CREAM = KIT / 'assets' / 'wss_logo_cream.png'
LOGO_GREEN = KIT / 'assets' / 'wss_logo_green.png'
LOGO_RATIO = 854 / 1079  # height / width of both logo files

# Set by init(): the package's assets folder and the deck title (used in footers).
A = None
TITLE = ''
prs = None
SLIDES = []


def init(package_dir, title):
    global A, TITLE, prs, BLANK
    A = Path(package_dir).resolve() / 'assets'
    TITLE = title
    prs = Presentation()
    prs.slide_width = Inches(SLIDE_W)
    prs.slide_height = Inches(SLIDE_H)
    # python-pptx's template is 4:3 and labels its size type="screen4x3". Changing the width
    # leaves that label behind, which contradicts the size; write the standard 16:9 values.
    sz = prs.element.sldSz
    sz.set('cx', '12192000'); sz.set('cy', '6858000')
    if 'type' in sz.attrib:
        del sz.attrib['type']
    BLANK = prs.slide_layouts[6]
    SLIDES.clear()


def rgb(h):
    return RGBColor.from_string(h)


def bg(slide, color):
    f = slide.background.fill
    f.solid()
    f.fore_color.rgb = rgb(color)


def new_slide(color=PAPER):
    s = prs.slides.add_slide(BLANK)
    bg(s, color)
    SLIDES.append(s)
    return s


def rect(slide, x, y, w, h, fill=None, line=None, lw=0.75, shape=MSO_SHAPE.RECTANGLE, radius=None):
    s = slide.shapes.add_shape(shape, Inches(x), Inches(y), Inches(w), Inches(h))
    if fill:
        s.fill.solid(); s.fill.fore_color.rgb = rgb(fill)
    else:
        s.fill.background()
    if line:
        s.line.color.rgb = rgb(line); s.line.width = Pt(lw)
    else:
        s.line.fill.background()
    s.shadow.inherit = False
    if radius is not None and shape == MSO_SHAPE.ROUNDED_RECTANGLE:
        s.adjustments[0] = radius / min(w, h)
    s.text_frame.text = ''
    return s


def rrect(slide, x, y, w, h, r=0.26, **kw):
    """Rounded card. r is the corner radius in inches (0.26 in = the site's 26px card)."""
    return rect(slide, x, y, w, h, shape=MSO_SHAPE.ROUNDED_RECTANGLE, radius=r, **kw)


def text(slide, x, y, w, h, runs, size=18, font=SERIF, color=INK, bold=False, italic=False,
         align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP, ls=None, space_after=0):
    """Real, editable text. runs: a str, or a list of paragraphs; a paragraph is a str
    or a list of (text, overrides) tuples, overrides being font/size/bold/italic/color."""
    tb = slide.shapes.add_textbox(Inches(x), Inches(y), Inches(w), Inches(h))
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    body_pr = tf._txBody.find(qn('a:bodyPr'))
    for el in list(body_pr):
        if el.tag in (qn('a:spAutoFit'), qn('a:normAutofit'), qn('a:noAutofit')):
            body_pr.remove(el)
    etree.SubElement(body_pr, qn('a:noAutofit'))
    paras = runs if isinstance(runs, list) else [runs]
    for i, para in enumerate(paras):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        if ls:
            p.line_spacing = ls
        if space_after:
            p.space_after = Pt(space_after)
        parts = para if isinstance(para, list) else [(para, {})]
        for part in parts:
            if isinstance(part, str):
                part = (part, {})
            t, o = part
            r = p.add_run()
            r.text = t
            f = r.font
            f.name = o.get('font', font)
            f.size = Pt(o.get('size', size))
            f.bold = o.get('bold', bold)
            f.italic = o.get('italic', italic)
            f.color.rgb = rgb(o.get('color', color))
    return tb


def picture(slide, path, x, y, w, h, radius_in=None):
    """Place an image (stretched to w x h: crop it to that ratio first). radius_in rounds the corners."""
    pic = slide.shapes.add_picture(str(path), Inches(x), Inches(y), Inches(w), Inches(h))
    if radius_in:
        pic.auto_shape_type = MSO_SHAPE.ROUNDED_RECTANGLE
        geom = pic._element.spPr.find(qn('a:prstGeom'))
        av = geom.find(qn('a:avLst'))
        if av is None:
            av = etree.SubElement(geom, qn('a:avLst'))
        for g in list(av):
            av.remove(g)
        gd = etree.SubElement(av, qn('a:gd'))
        gd.set('name', 'adj')
        gd.set('fmla', 'val %d' % int(radius_in / min(w, h) * 100000))
    return pic


def line(slide, x1, y1, x2, y2, color=HAIR, w=1.0):
    c = slide.shapes.add_connector(MSO_CONNECTOR.STRAIGHT, Inches(x1), Inches(y1), Inches(x2), Inches(y2))
    c.line.color.rgb = rgb(color)
    c.line.width = Pt(w)
    return c


def dot(slide, cx, cy, d, color):
    s = slide.shapes.add_shape(MSO_SHAPE.OVAL, Inches(cx - d / 2), Inches(cy - d / 2), Inches(d), Inches(d))
    s.fill.solid(); s.fill.fore_color.rgb = rgb(color); s.line.fill.background(); s.shadow.inherit = False
    return s


def footer(slide, n, dark=False):
    """Deck title and Society at left, two-digit slide number at right. Not on the title or Sláinte slides."""
    c = CREAM_MUTE if dark else MUTE
    text(slide, 0.85, 6.93, 6, 0.3, TITLE + '  ·  The Whiskey Share Society', size=10, font=SANS, color=c)
    text(slide, 11.48, 6.93, 1.0, 0.3, '%02d' % n, size=10, font=SANS, color=c, align=PP_ALIGN.RIGHT)


def heading(slide, y, t, size=38, color=INK, w=11.6, x=0.85, h=1.2):
    return text(slide, x, y, w, h, t, size=size, font=SANS, bold=True, color=color, ls=0.95)


def bottle_placeholder(slide, x, y, w, h):
    """A plain card with a quiet bottle silhouette, for bottles with no free photograph."""
    rrect(slide, x, y, w, h, r=0.26, fill=W100)
    cx = x + w / 2
    bw, bh = w * 0.42, h * 0.50
    by = y + h * 0.38
    rrect(slide, cx - bw / 2, by, bw, bh, r=0.32, fill=W200)
    nw, nh = bw * 0.30, h * 0.17
    rrect(slide, cx - nw / 2, by - nh + 0.05, nw, nh, r=0.06, fill=W200)
    rrect(slide, cx - nw * 0.62, by - nh - 0.12, nw * 1.24, 0.2, r=0.05, fill=W200)


def title_slide(title, hook, series='The Whiskey Share Society'):
    """Slide 1: logo, the deck's name, a short orange rule, the one-sentence hook."""
    s = new_slide(INK)
    picture(s, LOGO_CREAM, SLIDE_W / 2 - 1.55, 0.62, 3.1, 3.1 * LOGO_RATIO)
    text(s, 0.8, 3.38, 11.733, 1.0, title, size=52, font=SANS, bold=True, color=CREAM,
         align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    rect(s, SLIDE_W / 2 - 0.45, 4.55, 0.9, 0.045, fill=MARK)
    text(s, 2.4, 4.85, 8.533, 1.0, hook, size=20, italic=True, color=CREAM_MUTE, align=PP_ALIGN.CENTER, ls=1.15)
    text(s, 0.8, 6.55, 11.733, 0.35, series, size=11, font=SANS, color=CREAM_MUTE, align=PP_ALIGN.CENTER)
    return s


def slainte_slide(toast, word='Sláinte'):
    """The last slide: the logo comes back, the word, and a short closing thought. Nothing after it."""
    s = new_slide(INK)
    picture(s, LOGO_CREAM, SLIDE_W / 2 - 1.3, 0.75, 2.6, 2.6 * LOGO_RATIO)
    text(s, 0.8, 3.05, 11.733, 1.2, word, size=66, font=SANS, bold=True, color=CREAM,
         align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    rect(s, SLIDE_W / 2 - 0.45, 4.42, 0.9, 0.045, fill=MARK)
    text(s, 2.2, 4.72, 8.933, 1.2, toast, size=20, italic=True, color=CREAM_MUTE, align=PP_ALIGN.CENTER, ls=1.2)
    text(s, 0.8, 6.55, 11.733, 0.35, 'The Whiskey Share Society', size=11, font=SANS, color=CREAM_MUTE,
         align=PP_ALIGN.CENTER)
    return s


def glass_slide(n, glass, name, meta, body, facts, ask, photo=None, credit=None):
    """One pour: photo (or placeholder) at left, the glass line, name, meta line, two short
    paragraphs, a white card of three short facts, and an 'Ask the room' strip.
    photo is a file name in the package's assets/ folder, cropped to about 3.4 x 5.3."""
    s = new_slide()
    px, py, pw, ph = 0.85, 0.8, 3.4, 5.3
    if photo:
        picture(s, A / photo, px, py, pw, ph, radius_in=0.26)
    else:
        bottle_placeholder(s, px, py, pw, ph)
    if credit:
        text(s, px, py + ph + 0.1, pw, 0.45, credit, size=9.5, font=SANS, color=MUTE, ls=1.05)
    x = 4.85
    text(s, x, 0.8, 7.5, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (glass, {})]], size=15,
         font=SANS, bold=True, color=INK)
    text(s, x, 1.22, 7.6, 0.85, name, size=38, font=SANS, bold=True, color=INK, ls=0.95)
    text(s, x, 2.08, 7.6, 0.4, meta, size=14, font=SANS, color=MUTE)
    text(s, x, 2.7, 4.45, 3.2, body, size=16.5, ls=1.25, space_after=9)
    cx = 9.6
    rrect(s, cx, 2.7, 2.88, 3.2, r=0.26, fill=WHITE, line=HAIR)
    yy = 2.95
    for label, val in facts:
        text(s, cx + 0.28, yy, 2.4, 0.3, label, size=11.5, font=SANS, bold=True, color=MUTE)
        text(s, cx + 0.28, yy + 0.3, 2.4, 0.62, val, size=14, color=INK, ls=1.1)
        yy += 0.98
    rrect(s, x, 6.1, 7.63, 0.62, r=0.18, fill=W100)
    text(s, x + 0.3, 6.1, 7.1, 0.62, [[('Ask the room  ', {'font': SANS, 'bold': True, 'size': 12.5, 'italic': False}),
                                      (ask, {})]], size=15, italic=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    footer(s, n)
    return s


# ---------------------------------------------------------------- notes and save

def load_notes(md_path):
    """{n: (title, plain text)} from the '## [SLIDE n] Title' sections of speaker-notes.md."""
    md = Path(md_path).read_text()
    parts = re.split(r'^## \[SLIDE (\d+)\] (.*)$', md, flags=re.M)
    notes = {}
    for i in range(1, len(parts), 3):
        n, title, body = int(parts[i]), parts[i + 1].strip(), parts[i + 2]
        if n in notes:
            raise SystemExit('speaker-notes.md has two [SLIDE %d] sections' % n)
        notes[n] = (title, to_plain(body))
    return notes


def to_plain(body):
    """Markdown script -> presenter-view text: callouts become [LABEL] ..., stage directions [CUE] ..."""
    out = []
    for block in re.split(r'\n\s*\n', body.strip()):
        block = block.strip()
        if not block:
            continue
        if block.startswith('>'):
            lines = [l.lstrip('>').strip() for l in block.splitlines()]
            label = re.sub(r'\*\*(.*?)\*\*', r'\1', lines[0])
            rest = ' '.join(l for l in lines[1:] if l)
            out.append('[%s] %s' % (label, rest))
        elif re.fullmatch(r'_(.+)_', block, flags=re.S):
            out.append('[CUE] ' + block[1:-1].strip())
        else:
            b = re.sub(r'\*\*(.*?)\*\*', r'\1', block)
            b = re.sub(r'(?<!\w)_(.+?)_(?!\w)', r'\1', b)
            out.append(b)
    return '\n\n'.join(out)


def finish(notes_md, out_path):
    """Check slide n <-> [SLIDE n], fill every notes field, strip theme styles, save."""
    notes = load_notes(notes_md)
    expected = list(range(1, len(SLIDES) + 1))
    if sorted(notes) != expected:
        raise SystemExit('Deck has %d slides but speaker-notes.md has sections %s. Slide n must be [SLIDE n].'
                         % (len(SLIDES), sorted(notes)))
    for i, s in enumerate(SLIDES, 1):
        title, body = notes[i]
        s.notes_slide.notes_text_frame.text = '[SLIDE %d] %s\n\n%s' % (i, title, body)
    for sl in prs.slides:
        for el in list(sl.shapes._spTree.iter(qn('p:style'))):
            el.getparent().remove(el)
    prs.core_properties.title = TITLE
    prs.core_properties.author = 'The Whiskey Share Society'
    prs.save(str(out_path))
    return len(SLIDES)
