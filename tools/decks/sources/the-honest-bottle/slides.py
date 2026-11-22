"""The Honest Bottle: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/the-honest-bottle <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (the models are ../peat-reek and ../rye-country). The
photographs are cropped from that deck's slide images (no other copy was kept); their credits are
the old captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PX, PY, PW = 7.85, 0.75, 4.63   # photo panel on the right of a content slide


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, ratio, cap, dark=False, w=PW):
    """ratio: the crop's height / width, so the frame never stretches it. Right-aligned on R."""
    h = w * ratio
    x = R - w
    picture(s, A / name, x, PY, w, h, radius_in=0.26)
    credit(s, x, PY + h + 0.08, w, cap, color=CREAM_MUTE if dark else MUTE)


def rows_card(s, x, y, w, items, label_w, row_h, mark=None, label_size=20, size=17.5, pad=0.3):
    """A white hairline card of label / text rows. mark: index of the row to mark with an orange dot."""
    rrect(s, x, y, w, row_h * len(items) + 0.1, r=0.26, fill=WHITE, line=HAIR)
    yy = y + 0.05
    for i, (label, val) in enumerate(items):
        if i:
            line(s, x + pad, yy, x + w - pad, yy, HAIR, 1.0)
        if i == mark:
            dot(s, x + 0.16, yy + row_h / 2, 0.12, MARK_DEEP)
        text(s, x + pad, yy, label_w, row_h, label, size=label_size, font=SANS, bold=True, color=INK,
             anchor=MSO_ANCHOR.MIDDLE, ls=0.95)
        text(s, x + pad + label_w + 0.25, yy, w - 2 * pad - label_w - 0.25, row_h, val, size=size, color=INK,
             anchor=MSO_ANCHOR.MIDDLE, ls=1.15)
        yy += row_h


def strip(s, y, h, t, size=19):
    """A closing sentence in a light band across the content width."""
    rrect(s, X, y, CW, h, r=0.2, fill=W100)
    text(s, X + 0.3, y, CW - 0.6, h, t, size=size, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)


def pour_slide(n, pour, name, note, card=None, two_line_name=False, left=None, widths=(2.95, 3.15, 0.6)):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / Proof.
    card: (maker, style, proof), or None where the old slide had no such card (pour 2).
    left: draws something else in the placeholder's place (pour 2's label)."""
    s = new_slide()
    if left:
        left(s)
    else:
        bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.6, note, size=21, italic=True, color=INK, ls=1.2, space_after=8)
    if card:
        rrect(s, x, 4.6, w, 1.35, r=0.26, fill=WHITE, line=HAIR)
        cx = x + 0.3
        for label, val, cw_ in zip(('Maker', 'Style', 'Proof'), card, widths):
            text(s, cx, 4.85, cw_, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
            text(s, cx, 5.17, cw_, 0.6, val, size=18, color=INK, ls=1.1)
            cx += cw_ + 0.2
    footer(s, n)
    return s


def year_slide(n, year, head, body, quiet, photo, ratio, cap, body_y=4.45, dark=True, head_size=28, body_w=6.6):
    """The big-year story slide: year, orange rule, heading, body, photo right. dark=True is the
    deck's one green story slide; the other big-year slide sits on paper."""
    s = new_slide(INK if dark else PAPER)
    fg = CREAM if dark else INK
    quiet_c = CREAM_MUTE if dark else MUTE
    text(s, 0.75, 0.6, 6.6, 1.8, year, size=130, font=SANS, bold=True, color=fg, ls=0.9)
    rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK if dark else MARK_DEEP)
    text(s, X, 2.75, 6.7, 1.7, head, size=head_size, font=SANS, bold=True, color=fg, ls=0.98)
    paras = body if isinstance(body, list) else [body]
    if quiet:
        paras = paras + [[(quiet, {'color': quiet_c})]]
    text(s, X, body_y, body_w, 2.4, paras, size=18.5, color=fg, ls=1.2, space_after=12)
    photo_right(s, photo, ratio, cap, dark=dark)
    footer(s, n, dark=dark)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 3.0, 6.5, 1.0, 'The Honest Bottle', size=52, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.12, 0.9, 0.045, fill=MARK)
text(s, X, 4.35, 6.2, 0.45, 'Bottled in bond, 1897  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 4.95, 5.9, 1.5,
     ['What “bottled in bond” means on a', 'whiskey label, and the 1897 law it', 'comes from.'],
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 5.13
th = tw * 1285 / 1104
picture(s, A / 'saloon-black-hawk-1897.jpg', 7.35, 0.5, tw, th, radius_in=0.26)
credit(s, 7.35, 0.5 + th + 0.08, tw, 'A saloon in Black Hawk, Colorado, 1897. Library of Congress.',
       color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 sold from the barrel
s = new_slide()
heading(s, 0.7, ['In the 1870s, whiskey was sold', 'from the barrel.'], size=38, w=CW, h=1.4)
steps = [('Distillery', 'fills and brands the barrel'),
         ('Wholesaler', 'stores it and sells it on'),
         ('Saloon', 'sells it by the glass or jug'),
         ('Your glass', 'no bottle, label or seal')]
gap = 0.22
cw = (CW - 3 * gap) / 4
for i, (name, body) in enumerate(steps):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.35, cw, 2.5, r=0.26, fill=WHITE, line=HAIR)
    if i == 3:
        rect(s, cx + 0.3, 2.6, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.8, cw - 0.5, 0.6, name, size=26, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.55, cw - 0.5, 1.2, body, size=19, color=INK, ls=1.2)
strip(s, 5.2, 1.05, 'The barrel passed through other hands before it was poured, and any of them could '
      'change what was in it.', size=20)
footer(s, 2)

# ---------------------------------------------------------------- 3 straight and rectified
# The old slide's heading is its two column titles; the script heading names both.
s = new_slide()
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, 'Straight whiskey',
          ['Grain, mashed and distilled', 'A charred oak barrel',
           [('Years', {'bold': True}), (' of waiting', {})]]),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Rectified whiskey',
          ['Neutral spirit off a column still', 'Colour and flavour added',
           [('Sold ', {}), ('without', {'bold': True}), (' ageing', {})]])]
for (cx, fill, edge, col, name, rows) in sides:
    rrect(s, cx, 0.8, pw, 5.6, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.45, 1.2, pw - 0.9, 0.9, name, size=40, font=SANS, bold=True, color=col)
    if fill == OAK:
        rect(s, cx + 0.47, 2.15, 0.9, 0.045, fill=MARK)
    yy = 2.55
    for ln in rows:
        line(s, cx + 0.45, yy, cx + pw - 0.45, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.45, yy + 0.1, pw - 0.9, 0.85, [ln], size=24, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 1.05
footer(s, 3)

# ---------------------------------------------------------------- 4 pour 1
pour_slide(4, 'Pour 1 of 4', ['Evan Williams', 'Bottled-in-Bond'],
           'Try it neat first, then with a few drops of water.',
           card=('Heaven Hill, Kentucky', 'Kentucky straight bourbon', '100'), two_line_name=True)

# ---------------------------------------------------------------- 5 1870 (green story slide)
year_slide(5, '1870', ['Old Forester goes on sale', 'in sealed bottles.'],
           'George Garvin Brown sold medicines to doctors, who also prescribed whiskey and wanted a '
           'brand they could rely on.',
           'Each bottle carried his signed guarantee.',
           'brown-forman-louisville.jpg', 1255 / 1056,
           'Brown-Forman, the company Brown founded, in Louisville. Photo: Nyttend, public domain.',
           body_y=3.95, body_w=6.0)

# ---------------------------------------------------------------- 6 bonded warehouses
s = new_slide()
heading(s, 0.75, ['Bonded warehouses,', 'from 1868'], size=40, w=6.6, h=1.6)
rows_card(s, X, 2.45, 6.6, [
    ('Barrel in', 'Recorded on entry. No tax due yet.'),
    (['In the', 'warehouse'], 'A federal officer holds a key and logs every barrel.'),
    ('Barrel out', 'Recorded again. Tax paid.'),
], label_w=2.0, row_h=0.95, mark=1, label_size=21, size=18)
text(s, X, 5.5, 6.6, 1.0, 'The records showed who made each barrel, when, and how long it had been stored.',
     size=19, color=INK, ls=1.2)
photo_right(s, 'woodford-reserve-barrels.jpg', 1285 / 1056,
            'Barrels ageing at Woodford Reserve, Kentucky. Photo: Ken Thomas, public domain.')
footer(s, 6)

# ---------------------------------------------------------------- 7 Taylor and Carlisle
s = new_slide()
heading(s, 0.7, 'The two men behind the Act', size=38, w=CW, h=0.8)
hw = (CW - 0.4) / 2
ih = hw * 375 / 982
people = [(X, 'taylor-distillery-1891.jpg', 'The distillery of E. H. Taylor Jr. & Co., Frankfort, 1891 engraving.',
           'Col. Edmund Haynes Taylor Jr.',
           'Distiller in Frankfort, Kentucky, and a long-time opponent of the rectifiers.'),
          (X + hw + 0.4, 'carlisle-engraving.jpg', 'Carlisle, engraved by the Bureau of Engraving and Printing.',
           'John Griffin Carlisle',
           'Secretary of the Treasury, whose department ran the bonded warehouses.')]
for cx, img, cap, name, desc in people:
    picture(s, A / img, cx, 1.6, hw, ih, radius_in=0.2)
    credit(s, cx, 1.6 + ih + 0.06, hw, cap)
    text(s, cx, 4.1, hw, 0.5, name, size=23, font=SANS, bold=True, color=INK)
    text(s, cx, 4.6, hw, 0.8, desc, size=17.5, color=INK, ls=1.15)
strip(s, 5.55, 1.0, 'Taylor made straight whiskey, so the law helped his business. Rectifiers, George Garvin '
      'Brown among them, argued against it.', size=19)
footer(s, 7)

# ---------------------------------------------------------------- 8 3 March 1897 (on paper)
s = new_slide()
kicker(s, 'The Bottled-in-Bond Act becomes law', y=0.85, w=CW)
text(s, 0.75, 1.35, CW + 0.2, 1.8, '3 March 1897', size=120, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 3.25, 1.2, 0.045, fill=MARK_DEEP)
text(s, X, 3.6, 10.5, 1.2, 'Signed by Grover Cleveland on his last full day in office, nine years before the '
     'Pure Food and Drug Act.', size=24, color=INK, ls=1.2)
text(s, X, 4.95, CW, 0.6, 'Full title: “An Act to allow the bottling of distilled spirits in bond.” '
     'It was voluntary.', size=19, color=MUTE, ls=1.2)
footer(s, 8)

# ---------------------------------------------------------------- 9 what the label guarantees
s = new_slide()
heading(s, 0.85, 'What a bonded label guarantees', size=40, w=CW, h=0.9)
stats = [('1', 'distillery', ['One distiller,', 'one place.']),
         ('1', 'season', ['Jan–Jun', 'or Jul–Dec', 'of one year.']),
         ('4', 'years', ['At least, in a', 'bonded', 'warehouse.']),
         ('100', 'proof', ['50% alcohol,', 'no more or less.']),
         ('0', 'additions', ['Nothing but', 'water.'])]
g5 = 0.2
c5 = (CW - 4 * g5) / 5
for i, (big, label, body) in enumerate(stats):
    cx = X + i * (c5 + g5)
    rrect(s, cx, 1.95, c5, 3.35, r=0.24, fill=WHITE, line=HAIR)
    text(s, cx + 0.25, 2.15, c5 - 0.4, 1.0, big, size=56, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.25, 3.15, c5 - 0.4, 0.45, label, size=20, font=SANS, bold=True, color=MUTE)
    text(s, cx + 0.25, 3.7, c5 - 0.35, 1.5, body, size=17, color=INK, ls=1.15)
strip(s, 5.6, 0.85, 'The label must also name the distillery that made it.', size=20)
footer(s, 9)


# ---------------------------------------------------------------- 10 pour 2
def label_card(s):
    """The old slide's bottle label, with the three things to find, in the placeholder's place."""
    x, y, w, h = X, 0.8, 3.4, 5.3
    rrect(s, x, y, w, h, r=0.26, fill=WHITE, line=HAIR)
    rect(s, x + 0.35, y + 0.4, 2.0, 0.2, fill=W200)
    rect(s, x + 0.35, y + 0.75, 1.35, 0.1, fill=W200)
    items = [('1', 'BOTTLED IN BOND', 15.5, y + 1.35), ('2', '100 PROOF', 15.5, y + 2.25),
             ('3', 'Distilled at DSP-KY-___', 13, y + 3.95)]
    rect(s, x + 0.35, y + 3.05, 2.45, 0.08, fill=W200)
    rect(s, x + 0.35, y + 3.25, 1.8, 0.08, fill=W200)
    for num, t, sz, yy in items:
        dot(s, x + 0.55, yy + 0.2, 0.4, INK)
        text(s, x + 0.35, yy, 0.4, 0.4, num, size=14, font=SANS, bold=True, color=CREAM,
             align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
        text(s, x + 0.9, yy, w - 1.1, 0.4, t, size=sz, font=SANS, bold=True, color=INK,
             anchor=MSO_ANCHOR.MIDDLE)
        rect(s, x + 0.9, yy + 0.47, 0.7, 0.04, fill=MARK_DEEP)


pour_slide(10, 'Pour 2 of 4', 'Old Grand-Dad Bonded',
           [[('Jim Beam, Kentucky. A high-rye bourbon at 100 proof.', {'italic': False})],
            'Before you taste, find these three things on the bottle.'],
           left=label_card)

# ---------------------------------------------------------------- 11 1906 (big year, on paper)
year_slide(11, '1906', ['The Pure Food and Drug Act', 'starts an argument:', 'what is whisky?'],
           'Harvey Wiley, chief of the Bureau of Chemistry, wanted the word kept for straight whiskey. '
           'The rectifiers fought him until 1909.',
           None, 'wiley-laboratory.jpg', 1255 / 1056,
           'Harvey W. Wiley, right, in his laboratory. DC Public Library, no known copyright restrictions.',
           body_y=4.35, dark=False)

# ---------------------------------------------------------------- 12 Taft
s = new_slide()
heading(s, 0.75, ['December 1909: President', 'Taft rules on it himself.'], size=36, w=7.4, h=1.4)
rows_card(s, X, 2.4, 7.4, [
    ('Straight', 'Grain spirit aged in oak, nothing added.'),
    ('Blended', ['Straight whiskey mixed with', 'neutral-spirit whiskey,', 'labelled as a blend.']),
], label_w=1.7, row_h=1.25, mark=0, label_size=26, size=18.5)
text(s, X, 5.25, 7.3, 1.0, 'A bonded bourbon or rye is also a straight whiskey: four years in wood, nothing added.',
     size=20, color=INK, ls=1.2)
fh = 5.6
fw = fh * 864 / 1285
picture(s, A / 'taft-1909.jpg', R - fw, PY, fw, fh, radius_in=0.26)
credit(s, R - fw, PY + fh + 0.08, fw, 'William Howard Taft, 1909. Public domain.')
footer(s, 12)

# ---------------------------------------------------------------- 13 pour 3
pour_slide(13, 'Pour 3 of 4', ['Rittenhouse Rye', 'Bottled-in-Bond'],
           'The Act covers distilled spirits of any kind, not only bourbon.',
           card=('Heaven Hill, Kentucky', 'Straight rye whisky', '100'), two_line_name=True)

# ---------------------------------------------------------------- 14 what happened to bonded whiskey
s = new_slide()
heading(s, 0.65, 'What happened to bonded whiskey', size=40, w=CW, h=0.9)
events = [('1897', 'The Act passes.'),
          ('1920', 'Prohibition. Prescription whiskey is bottled in bond.'),
          ('1960s', 'Sales fall as drinkers move to vodka.'),
          ('1985', 'Federal strip stamps end.'),
          ('2010s', 'Bars and new small distilleries take it up again.')]
for i, (yr, body) in enumerate(events):
    cx = X + i * (c5 + g5)
    rrect(s, cx, 1.55, c5, 2.45, r=0.22, fill=WHITE, line=HAIR)
    if i == 4:
        rect(s, cx + 0.25, 1.75, 0.8, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.25, 1.83, c5 - 0.5, 0.6, yr, size=30, font=SANS, bold=True, color=INK)
    text(s, cx + 0.25, 2.47, c5 - 0.4, 1.45, body, size=16, color=INK, ls=1.15)
bw = CW
bh = bw * 405 / 2059
picture(s, A / 'prohibition-prescription.jpg', X, 4.15, bw, bh, radius_in=0.2)
credit(s, X, 4.15 + bh + 0.08, bw, 'A Prohibition-era prescription form for medicinal liquor. U.S. Treasury.')
footer(s, 14)

# ---------------------------------------------------------------- 15 pour 4
pour_slide(15, 'Pour 4 of 4', ['Old Forester', '1897'],
           'George Garvin Brown’s brand, in a bottling named after the year of the Act.',
           card=('Brown-Forman, Kentucky', 'Kentucky straight bourbon', '100'), two_line_name=True)

# ---------------------------------------------------------------- 16 reading the label
s = new_slide()
heading(s, 0.85, 'Reading an American whiskey label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('Bottled in bond', 'Defined by law since 1897. One distillery, one season, four years, 100 proof.'),
    ('Straight', 'Defined by law. Bourbon or rye aged at least two years in new charred oak.'),
    ('Age statement', 'Defined by law. The age of the youngest whiskey in the bottle.'),
    (['Small batch, reserve,', 'handcrafted'], 'No legal definition.'),
], label_w=3.5, row_h=1.08, label_size=22, size=19.5)
footer(s, 16)

# ---------------------------------------------------------------- 17 Sláinte
# The old deck's last slide is the logo and the word only; no closing line was written for it.
s = new_slide(INK)
picture(s, LOGO_CREAM, SLIDE_W / 2 - 1.5, 1.0, 3.0, 3.0 * LOGO_RATIO)
text(s, 0.8, 3.65, 11.733, 1.3, 'Sláinte.', size=72, font=SANS, bold=True, color=CREAM,
     align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
rect(s, SLIDE_W / 2 - 0.45, 5.15, 0.9, 0.045, fill=MARK)
text(s, 0.8, 6.55, 11.733, 0.35, 'The Whiskey Share Society', size=11, font=SANS, color=CREAM_MUTE,
     align=PP_ALIGN.CENTER)
