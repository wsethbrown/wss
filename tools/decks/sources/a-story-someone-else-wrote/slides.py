"""A Story Someone Else Wrote (Value vs. Prestige): slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py <this folder> <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

The tasting happens blind while slide 3 is up. Slides 4-9 are reveals, one
self-contained slide per sample: to drop a sample, delete its slide (and its
[SLIDE n] section), re-letter the rest, and fix the letters on the
same-distillery slide, the reveal table and B's discussion line.
"""
from PIL import Image
from pptx.util import Inches, Pt
from pptx.oxml.ns import qn
from lxml import etree

from wsskit import *
import wsskit


def place_bottle(s, path, x, y, w, h):
    """Fit a cut-out bottle photo inside the box, centred, keeping its proportions."""
    iw, ih = Image.open(path).size
    scale = min(w / iw, h / ih)
    bw, bh = iw * scale, ih * scale
    picture(s, path, x + (w - bw) / 2, y + (h - bh) / 2, bw, bh)


def label_line(s, x, y, w, t, color=INK, dot_color=MARK_DEEP):
    text(s, x, y, w, 0.4, [[('●  ', {'color': dot_color, 'size': 12}), (t, {})]], size=15, font=SANS,
         bold=True, color=color)


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, SLIDE_W / 2 - 1.45, 0.55, 2.9, 2.9 * LOGO_RATIO)
text(s, 0.8, 3.0, 11.733, 0.95, 'A Story Someone Else Wrote', size=50, font=SANS, bold=True, color=CREAM,
     align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
text(s, 0.8, 3.95, 11.733, 0.55, 'Value vs. Prestige', size=26, italic=True, color=CREAM,
     align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
rect(s, SLIDE_W / 2 - 0.45, 4.72, 0.9, 0.045, fill=MARK)
text(s, 2.4, 5.0, 8.533, 1.0,
     'A blind tasting of six whiskeys. Score each one, then see the names and prices.',
     size=20, italic=True, color=CREAM_MUTE, align=PP_ALIGN.CENTER, ls=1.15)
text(s, 0.8, 6.55, 11.733, 0.35, 'The Whiskey Share Society  ·  A blind tasting', size=11, font=SANS,
     color=CREAM_MUTE, align=PP_ALIGN.CENTER)

# ---------------------------------------------------------------- 2 the premise
s = new_slide()
label_line(s, 0.85, 0.85, 6.5, 'The premise')
heading(s, 1.3, 'Tonight is a blind tasting.', size=36, w=6.9, h=1.3)
text(s, 0.85, 2.85, 6.4, 3.6, [
    'A price reflects age, proof and barrel selection. It also reflects scarcity and marketing.',
    'Score each pour before you know what it is. Names and prices come at the end.',
    [('Then compare your scores with the prices.', {'bold': True})],
], size=18, ls=1.25, space_after=12)
rrect(s, 7.95, 0.85, 4.53, 5.65, r=0.36, fill=WHITE, line=HAIR)
rect(s, 8.4, 1.55, 0.9, 0.045, fill=MARK_DEEP)
text(s, 8.4, 1.85, 3.7, 2.9, 'A bottle’s price is a story someone else wrote.', size=32, italic=True,
     color=INK, ls=1.15)
text(s, 8.4, 4.55, 3.7, 1.2, 'Age, proof, scarcity, marketing.', size=18, font=SANS, color=MUTE, ls=1.2)
footer(s, 2)

# ---------------------------------------------------------------- 3 tips on tasting
s = new_slide()
label_line(s, 0.85, 0.85, 6.5, 'Before we pour')
heading(s, 1.3, 'Tips on tasting.', size=40, h=0.9)
tips = [
    ('Nose', 'Swirl the glass. Nose gently: short sniffs, mouth slightly open. Don’t bury your face in it.'),
    ('Palate', 'A small sip. Hold it a beat, then swallow and exhale through your nose.'),
    ('Finish', 'What flavors linger, and for how long? Try to look past the “spiciness”!'),
    ('Score', 'Write your number before you talk!'),
]
cw, gap, y0, ch = 2.75, 0.21, 2.55, 3.85
for i, (lab, body) in enumerate(tips):
    x = 0.85 + i * (cw + gap)
    rrect(s, x, y0, cw, ch, r=0.26, fill=WHITE, line=HAIR)
    rrect(s, x + 0.3, y0 + 0.32, 0.45, 0.45, r=0.15, fill=PAPER)
    text(s, x + 0.3, y0 + 0.32, 0.45, 0.45, str(i + 1), size=16, font=SANS, bold=True, color=INK,
         align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    text(s, x + 0.3, y0 + 1.0, cw - 0.55, 0.5, lab, size=24, font=SANS, bold=True, color=INK)
    text(s, x + 0.3, y0 + 1.6, cw - 0.55, 2.1, body, size=17, ls=1.25,
         bold=(lab == 'Score'))
footer(s, 3)


# ---------------------------------------------------------------- 4-9 the reveals, one slide per sample
def sample_slide(n, letter, name, meta, body, nose, taste, finish, photo, discussion=None):
    """One sample, revealed after scoring. Self-contained: delete the slide to drop the sample."""
    s = new_slide()
    px, py, pw, ph = 0.85, 0.8, 3.1, 5.92
    rrect(s, px, py, pw, ph, r=0.26, fill=W100)
    place_bottle(s, A / photo, px + 0.3, py + 0.35, pw - 0.6, ph - 0.7)
    x = 4.45
    rrect(s, x, 0.8, 1.0, 1.0, r=0.2, fill=INK)
    text(s, x, 0.8, 1.0, 1.0, letter, size=46, font=SANS, bold=True, color=CREAM, align=PP_ALIGN.CENTER,
         anchor=MSO_ANCHOR.MIDDLE)
    text(s, 5.7, 0.8, 6.8, 0.4, 'Sample ' + letter, size=15, font=SANS, bold=True, color=MUTE)
    text(s, 5.7, 1.15, 6.8, 0.7, name, size=29, font=SANS, bold=True, color=INK, ls=0.95)
    text(s, x, 2.08, 8.0, 0.4, meta, size=13.5, font=SANS, color=MUTE)
    text(s, x, 2.62, 4.6, 3.4, body, size=14.5, ls=1.22)
    cx, cy, cwid, chgt = 9.3, 2.62, 3.18, 3.36
    rrect(s, cx, cy, cwid, chgt, r=0.26, fill=WHITE, line=HAIR)
    yy = cy + 0.22
    for lab, val in (('Nose', nose), ('Taste', taste), ('Finish', finish)):
        text(s, cx + 0.28, yy, cwid - 0.5, 0.3, lab, size=11.5, font=SANS, bold=True, color=MUTE)
        text(s, cx + 0.28, yy + 0.27, cwid - 0.5, 0.7, val, size=12.5, color=INK, ls=1.08)
        yy += 1.02
    if discussion:
        rrect(s, x, 6.12, 8.03, 0.6, r=0.18, fill=W100)
        text(s, x + 0.3, 6.12, 7.5, 0.6, [[('Discussion  ', {'font': SANS, 'bold': True, 'size': 12.5,
                                                              'italic': False}), (discussion, {})]],
             size=13.5, italic=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    footer(s, n)
    return s


sample_slide(4, 'A', 'Buffalo Trace',
             'Buffalo Trace Distillery  ·  Frankfort, KY  ·  90 proof  ·  Mash Bill #1',
             'Buffalo Trace’s flagship bourbon. It has no age statement and is generally thought to be eight to ten '
             'years old. For most of its life it was easy to find at about twenty dollars. Demand has since made '
             'it an allocated bottle in many places.',
             'Caramel · Vanilla · Orange zest · Light oak',
             'Brown sugar · Honey · Summer fruit · Soft spice',
             'Short to medium · Oak · Cherry · Gentle pepper',
             'buffalo_trace.png')

sample_slide(5, 'B', 'Blanton’s Original',
             'Buffalo Trace Distillery  ·  Frankfort, KY  ·  93 proof  ·  Mash Bill #2',
             'The world’s first commercially marketed single-barrel bourbon, released in 1984 by Elmer T. Lee '
             'from Buffalo Trace’s metal-clad Warehouse H. The horse-and-jockey caps spell out B-L-A-N-T-O-N-S '
             'across eight different stoppers. It is well regarded and in high demand, and often sells for well '
             'above its list price.',
             'Honeysuckle · Vanilla · Citrus peel · Caramel',
             'Light caramel · Honey · Brown sugar · Charred oak',
             'Crisp, medium · Vanilla · Dry leather · Light peppercorn',
             'blantons.png',
             'Same distillery as sample A, different mash bill. Did A and B taste related?')

sample_slide(6, 'C', 'Evan Williams Bottled-in-Bond',
             'Heaven Hill Distillery  ·  Bardstown, KY  ·  100 proof  ·  Bottled-in-Bond',
             '“Bottled-in-bond” is a legal standard, not a marketing phrase. It requires the product of one '
             'distilling season, by one distiller, at one distillery; at least four years in a federally '
             'supervised warehouse; and bottling at exactly 100 proof. The Act behind it was '
             'signed in 1897, among the first consumer-protection laws in the country. It is the cheapest bottle '
             'on the table tonight, and the only one carrying a federal guarantee of what it is.',
             'Caramel · Vanilla · Peanut brittle · Toasted oak',
             'Brown sugar · Cornbread · Baking spice · Dark fruit',
             'Long & dry · Oak tannin · Cocoa · Lingering spice',
             'evan_williams_bib.png',
             'This was the cheapest pour, straight after the most expensive. How did you score it against B?')

sample_slide(7, 'D', 'Four Roses Small Batch Select',
             'Four Roses Distillery  ·  Lawrenceburg, KY  ·  104 proof  ·  Non-chill-filtered',
             'Four Roses runs ten distinct recipes, two mash bills crossed with five proprietary yeasts. This '
             'expression blends six of them, every barrel at least six years old, bottled without chill-filtering '
             'at 104 proof. It is a blend of recipes, not a single barrel.',
             'Apricot · Clove & nutmeg · Vanilla · Cedar / cigar box',
             'Raspberry jam · Black pepper · Cinnamon · Creamy vanilla',
             'Medium to long · Cinnamon caramel · Toasted oak · Mint chocolate',
             'four_roses_sbs.png')

sample_slide(8, 'E', 'Barrell Seagrass',
             'Barrell Craft Spirits  ·  Louisville, KY  ·  118.4 proof  ·  Cask strength',
             'This one is a rye, not a bourbon. Barrell does not distill; they source rye from the U.S. '
             'and Canada, then finish it separately in three different casks: Martinique rum, Madeira, and '
             'apricot brandy. The three are blended back together and bottled at cask strength.',
             'Apricot · Tropical fruit · Cedar · Rye spice',
             'Candied apricot · Rum sweetness · Vanilla & toffee · White pepper',
             'Medium · Spiced apricot · Rye bread · Salted peanut',
             'barrell_seagrass.png',
             'Did you notice it was not a bourbon?')

sample_slide(9, 'F', 'Elijah Craig Barrel Proof',
             'Heaven Hill Distillery  ·  Bardstown, KY  ·  118.2 proof  ·  10 yrs 7 mos',
             'Uncut and unfiltered, whatever strength it left the barrel at is exactly what is in the bottle. This '
             'release is 118.2 proof and ten years, seven months old; both change with every batch. A few drops of '
             'water change it noticeably. It is poured last because its heat lingers.',
             'Charred oak · Dark toffee · Vanilla bean · Flamed orange peel',
             'Brown sugar · Dark chocolate · Black pepper · Cherry cordial',
             'Long & hot · Chocolate · Torched sugar · Lingering spice',
             'elijah_craig_bp.png',
             'Did its strength raise or lower your score?')

# ---------------------------------------------------------------- 10 one thing to notice
s = new_slide(INK)
label_line(s, 0.85, 0.85, 6.5, 'One thing to notice', color=CREAM_MUTE, dot_color=MARK)
heading(s, 1.3, 'Samples A and B came from the same distillery.', size=36, color=CREAM, w=11.6, h=0.8)
pair = [('A', 'Buffalo Trace', '$40', 'Sample A  ·  90 proof  ·  Mash Bill #1', 'buffalo_trace.png'),
        ('B', 'Blanton’s', '$120', 'Sample B  ·  93 proof  ·  Mash Bill #2', 'blantons.png')]
for i, (letter, name, price, meta, photo) in enumerate(pair):
    x, y, w, h = 0.85 + i * 3.45, 2.45, 3.25, 4.05
    rrect(s, x, y, w, h, r=0.3, fill=OAK, line=OAK_EDGE)
    place_bottle(s, A / photo, x + 0.2, y + 0.3, 1.15, h - 0.6)
    tx = x + 1.5
    text(s, tx, y + 0.35, 1.6, 0.8, name, size=20, font=SANS, bold=True, color=CREAM, ls=1.0)
    text(s, tx, y + 1.35, 1.6, 0.8, price, size=40, font=SANS, bold=True, color=CREAM)
    text(s, tx, y + 2.3, 1.6, 1.4, meta.split('  ·  '), size=12.5, font=SANS, color=CREAM_MUTE, ls=1.2)
text(s, 8.0, 2.55, 4.48, 3.9,
     'Both are made by Buffalo Trace in Frankfort, Kentucky, from different mash bills. One sells for around '
     'forty dollars and the other for about three times that. Compare your scores for the two.',
     size=19, color=CREAM, ls=1.3)
footer(s, 10, dark=True)

# ---------------------------------------------------------------- 11 the reveal table
s = new_slide()
label_line(s, 0.85, 0.8, 6.5, 'The reveal')
heading(s, 1.22, 'The prices.', size=38, h=0.8)
text(s, 0.85, 1.95, 11.6, 0.45,
     'The room’s scores beside each bottle’s price.', size=16, italic=True, color=MUTE)
rows = [('', 'Bottle', 'Proof', 'Price', 'Room score', 'Room rank'),
        ('A', 'Buffalo Trace', '90', '$40', '', ''),
        ('B', 'Blanton’s Original', '93', '$120', '', ''),
        ('C', 'Evan Williams Bottled-in-Bond', '100', '$18', '', ''),
        ('D', 'Four Roses Small Batch Select', '104', '$60', '', ''),
        ('E', 'Barrell Seagrass', '118.4', '$75', '', ''),
        ('F', 'Elijah Craig Barrel Proof', '118.2', '$80', '', '')]
widths = [0.7, 4.53, 1.2, 1.2, 2.0, 2.0]
gf = s.shapes.add_table(len(rows), len(widths), Inches(0.85), Inches(2.6), Inches(sum(widths)),
                        Inches(0.5 * len(rows)))
tbl = gf.table
tblPr = tbl._tbl.tblPr
for k in ('firstRow', 'bandRow'):
    tblPr.set(k, '0')
sid = tblPr.find(qn('a:tableStyleId'))
if sid is not None:
    sid.text = '{5940675A-B579-460E-94D1-54222C63F5DA}'  # "No Style, Table Grid"


def cell_border(cell, color, w_pt=0.75, sides=('L', 'R', 'T', 'B')):
    tcPr = cell._tc.get_or_add_tcPr()
    for side in ('L', 'R', 'T', 'B'):
        tag = qn('a:ln' + side)
        for old in tcPr.findall(tag):
            tcPr.remove(old)
    for side in ('L', 'R', 'T', 'B'):
        ln = etree.SubElement(tcPr, qn('a:ln' + side), w=str(int(w_pt * 12700)) if side in sides else '0')
        if side in sides:
            sf = etree.SubElement(ln, qn('a:solidFill'))
            etree.SubElement(sf, qn('a:srgbClr'), val=color)
        else:
            etree.SubElement(ln, qn('a:noFill'))


for j, wd in enumerate(widths):
    tbl.columns[j].width = Inches(wd)
for i, row in enumerate(rows):
    tbl.rows[i].height = Inches(0.5)
    for j, val in enumerate(row):
        c = tbl.cell(i, j)
        c.fill.solid()
        c.fill.fore_color.rgb = wsskit.rgb(INK if i == 0 else (WHITE if j < 4 else PAPER))
        c.margin_left = c.margin_right = Inches(0.14)
        c.margin_top = c.margin_bottom = Inches(0.04)
        c.vertical_anchor = MSO_ANCHOR.MIDDLE
        tf = c.text_frame
        tf.text = val
        p = tf.paragraphs[0]
        p.alignment = PP_ALIGN.LEFT if j in (0, 1) else PP_ALIGN.CENTER
        r = p.runs[0] if p.runs else p.add_run()
        f = r.font
        f.name = SANS
        f.size = Pt(14 if i == 0 else 16)
        f.bold = (i == 0 or j == 0)
        f.color.rgb = wsskit.rgb(CREAM if i == 0 else INK)
        cell_border(c, HAIR)
text(s, 0.85, 6.25, 11.6, 0.4,
     'Approximate US prices, checked November 2026. Blanton’s at its usual street price; its list price is lower.',
     size=11, font=SANS, color=MUTE)
footer(s, 11)

# ---------------------------------------------------------------- 12 the point
s = new_slide()
label_line(s, 0.85, 0.85, 6.5, 'The point')
heading(s, 1.3, 'You scored these without knowing what they cost.',
        size=36, w=11.2, h=1.8)
rrect(s, 0.85, 3.25, 11.63, 2.95, r=0.3, fill=WHITE, line=HAIR)
text(s, 1.35, 3.6, 10.6, 2.3,
     'Sometimes a higher price buys more age, more proof or better barrels. Sometimes it buys scarcity and a '
     'story. Your scores show which of tonight’s bottles were worth it to you.',
     size=22, ls=1.3)
footer(s, 12)

# ---------------------------------------------------------------- 13 Sláinte
slainte_slide('Pour another of whichever you scored highest.')
