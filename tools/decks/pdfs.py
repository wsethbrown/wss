"""Render speaker-notes.md and research-outline.md to branded PDFs (reportlab).

Normally run by build.py. On its own:
    python3 -I tools/decks/pdfs.py <source_dir> [out_dir]
reads <source_dir>/deck.json (slug, title, subtitle), speaker-notes.md and
research-outline.md, and writes <slug>-speaker-notes.pdf and
<slug>-research-outline.pdf into out_dir (default: source_dir).
The full dialect, with examples, is in
.claude/skills/wss-deck-speaker-notes/reference/markdown-dialect.md.

Markdown dialect (the WSS notes/outline dialect):
  # Title / ## Heading / ### Subheading      (the first H1 and the two lines after it form the cover band)
  ## [SLIDE n] Title                          slide section: small "SLIDE n" label + heading
  _A whole paragraph in underscores_          stage direction (green italic)
  > **LABEL**  + more > lines                 callout box (tinted, orange left rule)
  - item  /  - › _source_                     bullets / source list
  ---                                          section break (new page in the notes)
  **bold**, _italic_ inline
"""
import json
import re
import sys
from pathlib import Path

from reportlab.lib.colors import HexColor
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, CondPageBreak, Frame, Image, KeepTogether, PageBreak,
                                PageTemplate, Paragraph, Spacer, Table, TableStyle)

SERIES = 'The Whiskey Share Society'
KIT = Path(__file__).resolve().parent
F = KIT / 'fonts'
LOGO = KIT / 'assets' / 'wss_logo_cream.png'

pdfmetrics.registerFont(TTFont('Oswald', str(F / 'Oswald.ttf')))
pdfmetrics.registerFont(TTFont('Crimson', str(F / 'CrimsonText-Regular.ttf')))
pdfmetrics.registerFont(TTFont('Crimson-Italic', str(F / 'CrimsonText-Italic.ttf')))
pdfmetrics.registerFont(TTFont('Crimson-Bold', str(F / 'CrimsonText-Bold.ttf')))
pdfmetrics.registerFont(TTFont('Crimson-BoldItalic', str(F / 'CrimsonText-BoldItalic.ttf')))
pdfmetrics.registerFontFamily('Crimson', normal='Crimson', bold='Crimson-Bold', italic='Crimson-Italic',
                              boldItalic='Crimson-BoldItalic')

# site palette
BAND = HexColor('#16332A'); PAGE = HexColor('#F6F4EE'); INK = HexColor('#1B2A24'); GREEN = HexColor('#16332A')
MUTE = HexColor('#5F6B64'); HAIR = HexColor('#C9CFC6'); MARK = HexColor('#E65C00'); MARK_ON_GREEN = HexColor('#FF6D00')
CREAM = HexColor('#F6F4EE'); CREAM_MUTE = HexColor('#B9C6BE'); STAGE = HexColor('#4C7A5C'); CALLOUT = HexColor('#E8E7DD')

M = 58  # side margin, pt
W, H = letter

S = {
    'body': ParagraphStyle('body', fontName='Crimson', fontSize=12.2, leading=17.5, textColor=INK, spaceAfter=8),
    'h1': ParagraphStyle('h1', fontName='Oswald', fontSize=19, leading=23, textColor=GREEN, spaceBefore=6, spaceAfter=6),
    'h2': ParagraphStyle('h2', fontName='Oswald', fontSize=19, leading=23, textColor=GREEN, spaceBefore=4, spaceAfter=5),
    'h3': ParagraphStyle('h3', fontName='Oswald', fontSize=12.5, leading=16, textColor=GREEN, spaceBefore=10, spaceAfter=4),
    'slide': ParagraphStyle('slide', fontName='Oswald', fontSize=8.8, leading=11, textColor=MUTE, spaceBefore=14, spaceAfter=2),
    'stage': ParagraphStyle('stage', fontName='Crimson-Italic', fontSize=10.6, leading=14.5, textColor=STAGE, spaceAfter=8),
    'bullet': ParagraphStyle('bullet', fontName='Crimson', fontSize=11, leading=15, textColor=INK, leftIndent=13,
                             bulletIndent=2, spaceAfter=3),
    'src': ParagraphStyle('src', fontName='Crimson-Italic', fontSize=10, leading=13.5, textColor=MUTE, leftIndent=13,
                          bulletIndent=2, spaceAfter=2),
    'clabel': ParagraphStyle('clabel', fontName='Oswald', fontSize=9.4, leading=12, textColor=GREEN, spaceAfter=4),
    'cbody': ParagraphStyle('cbody', fontName='Crimson', fontSize=10.6, leading=14.5, textColor=INK, spaceAfter=3),
}


def inline(t):
    t = t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'(?<![\w/])_(.+?)_(?![\w/])', r'<i>\1</i>', t)
    t = re.sub(r'`(.+?)`', r'\1', t)
    return t


def callout(lines):
    label = re.sub(r'\*\*(.*?)\*\*', r'\1', lines[0]).strip()
    body = [Paragraph(label.upper(), S['clabel'])]
    for l in lines[1:]:
        if l.strip():
            body.append(Paragraph(inline(l.strip()), S['cbody']))
    t = Table([[body]], colWidths=[W - 2 * M])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), CALLOUT),
        ('LINEBEFORE', (0, 0), (0, -1), 2.2, MARK),
        ('LEFTPADDING', (0, 0), (-1, -1), 11), ('RIGHTPADDING', (0, 0), (-1, -1), 11),
        ('TOPPADDING', (0, 0), (-1, -1), 9), ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
    ]))
    return [Spacer(1, 4), t, Spacer(1, 10)]


def parse(md, doc_kind):
    lines = md.splitlines()
    # cover: first H1 + following non-empty lines until a blank-blank or a non-plain line
    i = 0
    while not lines[i].startswith('# '):
        i += 1
    i += 1
    cover = []
    while i < len(lines) and not lines[i].startswith(('#', '>', '_', '-')):
        if lines[i].strip():
            cover.append(lines[i].strip())
        i += 1
    flow = []
    para = []

    def flush():
        if para:
            txt = ' '.join(para).strip()
            if re.fullmatch(r'_(.+)_', txt, flags=re.S):
                flow.append(Paragraph(inline(txt[1:-1]), S['stage']))
            else:
                flow.append(Paragraph(inline(txt), S['body']))
            para.clear()

    while i < len(lines):
        l = lines[i]
        if not l.strip():
            flush(); i += 1; continue
        if l.startswith('>'):
            flush()
            block = []
            while i < len(lines) and lines[i].startswith('>'):
                block.append(lines[i].lstrip('>').strip()); i += 1
            flow += callout(block)
            continue
        m = re.match(r'^## \[SLIDE (\d+)\] (.*)$', l)
        if m:
            flush()
            flow.append(CondPageBreak(1.6 * inch))
            flow.append(Paragraph('SLIDE %s' % m.group(1), S['slide']))
            flow.append(Paragraph(inline(m.group(2)), S['h2']))
            i += 1; continue
        if l.startswith('## '):
            flush()
            flow.append(CondPageBreak(1.8 * inch))
            t = l[3:].strip()
            mm = re.match(r'^Module (\d+)\. (.*)$', t)
            if mm:
                flow.append(Paragraph('MODULE %s' % mm.group(1), S['slide']))
                t = mm.group(2)
            flow.append(Paragraph(inline(t), S['h2']))
            i += 1; continue
        if l.startswith('### '):
            flush()
            flow.append(CondPageBreak(1.2 * inch))
            flow.append(Paragraph(inline(l[4:].strip()).upper(), S['h3']))
            i += 1; continue
        if l.strip() == '---':
            flush()
            if doc_kind == 'notes':
                flow.append(PageBreak())
            i += 1; continue
        if l.startswith('- '):
            flush()
            item = l[2:].strip()
            i += 1
            while i < len(lines) and lines[i].startswith('  ') and lines[i].strip():
                item += ' ' + lines[i].strip(); i += 1
            if item.startswith('›'):
                flow.append(Paragraph(inline(item[1:].strip()), S['src'], bulletText='›'))
            else:
                flow.append(Paragraph(inline(item), S['bullet'], bulletText='•'))
            continue
        para.append(l.strip())
        i += 1
    flush()
    return cover, flow


def build(src_path, out_path, kind, label, TITLE, SUB):
    md = Path(src_path).read_text()
    cover, flow = parse(md, kind)
    logo = str(LOGO)
    band_h = 108

    def first(c, d):
        c.saveState()
        c.setFillColor(PAGE); c.rect(0, 0, W, H, stroke=0, fill=1)
        c.setFillColor(BAND); c.rect(0, H - band_h, W, band_h, stroke=0, fill=1)
        c.setStrokeColor(MARK_ON_GREEN); c.setLineWidth(2.2); c.line(0, H - band_h, W, H - band_h)
        lw = 92; lh = lw * 854 / 1079
        c.drawImage(logo, M - 6, H - band_h + (band_h - lh) / 2, lw, lh, mask='auto')
        x = M + lw + 14
        c.setFillColor(MARK_ON_GREEN); c.setFont('Oswald', 9); c.drawString(x, H - 36, label.upper())
        c.setFillColor(CREAM); c.setFont('Oswald', 25); c.drawString(x, H - 64, TITLE)
        c.setFillColor(CREAM_MUTE); c.setFont('Crimson-Italic', 11.5); c.drawString(x, H - 84, SUB)
        footer(c, d)
        c.restoreState()

    def later(c, d):
        c.saveState()
        c.setFillColor(PAGE); c.rect(0, 0, W, H, stroke=0, fill=1)
        c.setFillColor(MUTE); c.setFont('Oswald', 8.8); c.drawString(M, H - 41, TITLE.upper() + '  ·  ' + label.upper())
        c.setFont('Crimson-Italic', 8.8); c.drawRightString(W - M, H - 41, SERIES)
        c.setStrokeColor(HAIR); c.setLineWidth(0.6); c.line(M, H - 50, W - M, H - 50)
        footer(c, d)
        c.restoreState()

    def footer(c, d):
        c.setStrokeColor(HAIR); c.setLineWidth(0.6); c.line(M, 55, W - M, 55)
        c.setFillColor(MUTE); c.setFont('Crimson-Italic', 8.6)
        c.drawString(M, 41, '%s  ·  %s  ·  %s' % (SERIES, TITLE, label))
        c.setFillColor(GREEN); c.setFont('Oswald', 8.6); c.drawRightString(W - M, 41, str(d.page))

    doc = BaseDocTemplate(str(out_path), pagesize=letter, leftMargin=M, rightMargin=M, topMargin=70,
                          bottomMargin=72, title='%s: %s' % (TITLE, label), author=SERIES)
    f1 = Frame(M, 72, W - 2 * M, H - band_h - 30 - 72, id='f1', leftPadding=0, rightPadding=0, topPadding=0,
               bottomPadding=0)
    f2 = Frame(M, 72, W - 2 * M, H - 70 - 72, id='f2', leftPadding=0, rightPadding=0, topPadding=0, bottomPadding=0)
    doc.addPageTemplates([PageTemplate('first', [f1], onPage=first, autoNextPageTemplate='later'),
                          PageTemplate('later', [f2], onPage=later)])
    intro = [Paragraph(inline(TITLE), S['h1'])]
    for cl in cover[:2]:
        intro.append(Paragraph(inline(cl), ParagraphStyle('ci', parent=S['body'], fontName='Crimson-Italic' if cl == cover[0] else 'Crimson')))
    doc.build(intro + flow)
    print('wrote', out_path)


def build_all(src_dir, out_dir=None):
    src = Path(src_dir).resolve()
    out = Path(out_dir).resolve() if out_dir else src
    meta = json.loads((src / 'deck.json').read_text())
    title, sub, slug = meta['title'], meta.get('subtitle', ''), meta['slug']
    build(src / 'speaker-notes.md', out / (slug + '-speaker-notes.pdf'), 'notes', "Speaker's notes", title, sub)
    build(src / 'research-outline.md', out / (slug + '-research-outline.pdf'), 'outline', 'Research outline', title, sub)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    build_all(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
