"""Peated Scotch: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/peated-scotch <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit. The photographs are cropped from that deck's slide
images (no other copy was kept); their credits are the old captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PX, PY, PW = 7.85, 0.75, 4.63   # photo panel on the right of a content slide
PH = PW * 1255 / 1056           # the cropped photos are 1056 x 1255


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, cap, dark=False):
    picture(s, A / name, PX, PY, PW, PH, radius_in=0.26)
    credit(s, PX, PY + PH + 0.08, PW, cap, color=CREAM_MUTE if dark else MUTE)


def rows_card(s, x, y, w, items, label_w, row_h, mark=None, label_size=20, size=17.5, pad=0.3):
    """A white hairline card of label / text rows. mark: index of the row to mark with an orange dot."""
    rrect(s, x, y, w, row_h * len(items) + 0.1, r=0.26, fill=WHITE, line=HAIR)
    yy = y + 0.05
    for i, (label, val) in enumerate(items):
        if i:
            line(s, x + pad, yy, x + w - pad, yy, HAIR, 1.0)
        lx = x + pad
        if i == mark:
            dot(s, x + 0.16, yy + row_h / 2, 0.12, MARK_DEEP)
        text(s, lx, yy, label_w, row_h, label, size=label_size, font=SANS, bold=True, color=INK,
             anchor=MSO_ANCHOR.MIDDLE, ls=0.95)
        text(s, x + pad + label_w + 0.25, yy, w - 2 * pad - label_w - 0.25, row_h, val, size=size, color=INK,
             anchor=MSO_ANCHOR.MIDDLE, ls=1.15)
        yy += row_h


def pour_slide(n, pour, name, note, maker, style, abv, two_line_name=False):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / ABV."""
    s = new_slide()
    bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=21, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.35, r=0.26, fill=WHITE, line=HAIR)
    cols = [('Maker', maker, 2.55), ('Style', style, 3.35), ('ABV', abv, 1.1)]
    cx = x + 0.3
    for label, val, cw in cols:
        text(s, cx, 4.85, cw, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw, 0.6, val, size=18, color=INK, ls=1.1)
        cx += cw + 0.2
    footer(s, n)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 2.95, 6.2, 1.0, 'Peated Scotch', size=60, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.12, 0.9, 0.045, fill=MARK)
text(s, X, 4.35, 6.2, 0.45, 'Peat smoke in Scotch  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 4.95, 5.9, 1.5,
     'Why Scottish distillers dried their malt over peat, and how four distilleries came to use a '
     'great deal of it or none.', size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 5.13
picture(s, A / 'barnard-ardbeg-1887.jpg', 7.35, 0.6, tw, tw * 1255 / 1104, radius_in=0.26)
credit(s, 7.35, 0.6 + tw * 1255 / 1104 + 0.08, tw,
       'Ardbeg distillery, Islay. Engraving from Alfred Barnard’s survey of distilleries, 1887. Public domain.',
       color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 peat
s = new_slide()
heading(s, 0.75, 'Peat, the fuel of a country with few trees', size=36, w=6.6, h=1.3)
rows_card(s, X, 2.3, 6.55, [
    ('The bog', ['moss and heather, too wet', 'and acid to rot']),
    ('The bank', 'cut into slabs with a tusker'),
    ('The moss', 'slabs spread out to dry in the wind'),
    ('Home', 'stacked by the house to burn'),
], label_w=1.75, row_h=0.95, mark=3)
photo_right(s, 'turner-peat-bog-1812.jpg',
            'Peat cutters, from J. M. W. Turner’s print “Peat Bog, Scotland”, 1812. National Gallery of Art, public domain.')
footer(s, 2)

# ---------------------------------------------------------------- 3 kiln
s = new_slide()
heading(s, 0.85, 'Drying malt over a peat fire', size=40, w=CW, h=0.9)
steps = [('Steep', 'Barley soaked in water.'),
         ('Sprout', 'Spread out until it starts to grow.'),
         ('Kiln, wet', 'Peat smoke. The damp grain takes up phenols.'),
         ('Kiln, dry', 'Hot air finishes it. Little more smoke goes in.')]
gap = 0.22
cw = (CW - 3 * gap) / 4
for i, (t, body) in enumerate(steps):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.1, cw, 3.0, r=0.26, fill=WHITE, line=HAIR)
    if i == 2:
        rect(s, cx + 0.3, 2.35, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.55, cw - 0.6, 0.6, t, size=26, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.3, cw - 0.55, 1.7, body, size=18, color=INK, ls=1.2)
rrect(s, X, 5.45, CW, 0.8, r=0.2, fill=W100)
text(s, X + 0.3, 5.45, CW - 0.6, 0.8, 'Around 1800, peat was the fuel at hand across the Highlands and islands.',
     size=20, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 3)

# ---------------------------------------------------------------- 4 Glenmorangie
s = new_slide()
heading(s, 0.75, 'Glenmorangie kept burning peat long after the railway came', size=38, w=CW, h=1.3)
rows_card(s, X, 2.3, CW, [
    ('1843', 'William Matheson licenses a distillery at Tain. Production starts in 1849.'),
    ('1864', 'The railway reaches Tain.'),
    ('1880s', 'Alfred Barnard visits and records peat as the only fuel used there.'),
    ('1977', 'Its own maltings close. Malt is bought in at 2 ppm or less, which the trade calls unpeated.'),
], label_w=1.75, row_h=1.0, mark=3, label_size=28, size=19)
footer(s, 4)

# ---------------------------------------------------------------- 5 pour 1
pour_slide(5, 'Pour 1 of 4', ['Glenmorangie', 'The Original'],
           ['Malt with next to no peat in it.'],
           'Glenmorangie, Tain', 'Highland single malt, 12 years', '40%', two_line_name=True)

# ---------------------------------------------------------------- 6 Islay
s = new_slide()
heading(s, 0.75, 'Islay kept burning peat', size=38, w=6.6, h=0.8)
rows_card(s, X, 1.8, 6.55, [
    ('Fuel', 'Peat banks close to the distilleries'),
    ('Coal', 'No railway, so it came by boat'),
    ('Buyers', 'Blenders paid for a smoky malt'),
], label_w=1.5, row_h=0.95, mark=2)
text(s, X, 5.05, 6.55, 0.5, 'Bowmore, on Loch Indaal, is first recorded in 1779.', size=18, color=INK)
photo_right(s, 'loch-indaal-port-charlotte.jpg',
            'Loch Indaal from Port Charlotte, Islay, 2006. Photo: Calum Hutchinson, public domain.')
footer(s, 6)

# ---------------------------------------------------------------- 7 Bowmore
s = new_slide()
heading(s, 0.75, ['Bowmore still turns', 'its own malt'], size=36, w=6.6, h=1.3)
rows_card(s, X, 2.3, 6.55, [
    ('Floor', ['Wet barley spread out and turned', 'by hand while it sprouts.']),
    ('Kiln', ['Islay peat burned under it', 'while it is damp.']),
    ('Bought in', ['The rest of the malt, made to', 'the same level of smoke.']),
], label_w=1.75, row_h=1.0, mark=1, size=17)
text(s, X, 5.6, 6.55, 0.8, ['Laphroaig, along the south coast, also keeps', 'a malting floor.'],
     size=18, italic=True, color=MUTE, ls=1.15)
photo_right(s, 'peat-fire-grate.jpg', 'Peat burning in a domestic grate. Photo: Cqui, public domain.')
footer(s, 7)

# ---------------------------------------------------------------- 8 pour 2
pour_slide(8, 'Pour 2 of 4', 'Bowmore 12',
           ['Usually described as medium peated.',
            'The same age and strength as the Glenmorangie, made from peated malt.'],
           'Bowmore, Islay', 'Islay single malt, 12 years', '40%')

# ---------------------------------------------------------------- 9 ppm
s = new_slide()
heading(s, 0.85, 'The ppm figure measures the malt', size=40, w=CW, h=0.9)
text(s, X, 1.75, CW, 0.5, 'Parts per million of phenols, tested in a laboratory before anything is distilled.',
     size=20, italic=True, color=MUTE)
cols = [('Malt', 'The ppm figure is measured here.'),
        ('Still', 'Heavy phenols come late. Where the cut falls decides how many are kept.'),
        ('Cask', 'Smoke fades with each year in wood.'),
        ('Glass', 'Lower than the malt. The label cannot tell you by how much.')]
for i, (t, body) in enumerate(cols):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.65, cw, 3.55, r=0.26, fill=WHITE, line=HAIR)
    if i == 0:
        rect(s, cx + 0.3, 2.9, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 3.1, cw - 0.6, 0.6, t, size=28, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.85, cw - 0.55, 2.2, body, size=18, color=INK, ls=1.2)
footer(s, 9)

# ---------------------------------------------------------------- 10 1973 (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 6.4, 1.8, '1973', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 6.5, 1.2, 'The Port Ellen maltings open on Islay.', size=32, font=SANS, bold=True, color=CREAM,
     ls=0.95)
text(s, X, 4.1, 6.5, 2.4, [
    'Built by the Distillers Company beside its Port Ellen distillery, to make peated malt for its Islay distilleries.',
    [('Caol Ila and Lagavulin take much or all of their malt from Port Ellen.', {'color': CREAM_MUTE})],
], size=18.5, color=CREAM, ls=1.2, space_after=12)
photo_right(s, 'port-ellen-from-ferry.jpg', 'Port Ellen, Islay, seen from the ferry, 2010. Photo: Johan Florin, public domain.',
            dark=True)
footer(s, 10, dark=True)

# ---------------------------------------------------------------- 11 Caol Ila
s = new_slide()
heading(s, 0.85, 'Caol Ila, rebuilt 1972–74', size=40, w=CW, h=0.9)
stats = [('1846', 'founded', 'At Port Askaig, facing Jura across the Sound of Islay.'),
         ('2 → 6', 'stills', 'The rebuild tripled the number of stills.'),
         ('Blends', 'destination', 'Most of it goes into blends, including Johnnie Walker.')]
g3 = 0.25
c3 = (CW - 2 * g3) / 3
for i, (big, label, body) in enumerate(stats):
    cx = X + i * (c3 + g3)
    rrect(s, cx, 2.05, c3, 3.75, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.35, 2.3, c3 - 0.7, 1.2, big, size=64, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.35, 3.55, c3 - 0.7, 0.5, label, size=22, font=SANS, bold=True, color=MUTE)
    text(s, cx + 0.35, 4.25, c3 - 0.6, 1.4, body, size=17.5, color=INK, ls=1.2)
footer(s, 11)

# ---------------------------------------------------------------- 12 pour 3
pour_slide(12, 'Pour 3 of 4', 'Caol Ila 12',
           ['Malt largely from Port Ellen, and a whisky made mostly for blending.'],
           'Caol Ila, Islay', 'Islay single malt, 12 years', '43%')

# ---------------------------------------------------------------- 13 closures
s = new_slide()
heading(s, 0.85, 'Closures on Islay, 1981–1996', size=40, w=CW, h=0.9)
events = [('1981', 'Ardbeg, owned by Hiram Walker, stops production.'),
          ('1983', 'Port Ellen distillery closes. The maltings keep working.'),
          ('1989', 'Ardbeg starts again at a low level.'),
          ('1996', 'Ardbeg stops again. Allied Domecq puts it up for sale.')]
for i, (yr, body) in enumerate(events):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.05, cw, 2.95, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.3, 2.25, cw - 0.6, 0.75, yr, size=40, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.1, cw - 0.5, 1.8, body, size=17, color=INK, ls=1.2)
rrect(s, X, 5.3, CW, 1.15, r=0.2, fill=W100)
text(s, X + 0.3, 5.3, CW - 0.6, 1.15,
     'Production in the 1960s and 1970s had run far ahead of demand. In 1983 the Distillers Company closed '
     '11 of its 45 malt distilleries.', size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)
footer(s, 13)

# ---------------------------------------------------------------- 14 1997
s = new_slide()
heading(s, 0.85, '1997: Glenmorangie buys Ardbeg', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, 'Glenmorangie',
          ['Tain, on the mainland', 'Malt at 2 ppm or less',
           [('The buyer, ', {}), ('1997', {'bold': True}), (', for £7 million', {})]], None),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Ardbeg',
          ['Islay, on the south coast', 'Peated malt from Port Ellen',
           [('Restarted, ', {}), ('1997', {'bold': True})]], 'Both owned by LVMH since 2004.')]
for (cx, fill, edge, col, name, lines_, note) in sides:
    rrect(s, cx, 2.0, pw, 4.45, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.25, pw - 0.8, 0.75, name, size=34, font=SANS, bold=True, color=col)
    yy = 3.1
    for ln in lines_:
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.4, yy + 0.08, pw - 0.8, 0.6, [ln], size=21, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 0.72
    if note:
        text(s, cx + 0.4, yy + 0.2, pw - 0.8, 0.5, note, size=17, color=CREAM_MUTE)
rect(s, X + pw + 0.25 + 0.42, 3.0, 0.9, 0.045, fill=MARK)
footer(s, 14)

# ---------------------------------------------------------------- 15 ppm chart
s = new_slide()
heading(s, 0.85, 'Peat in the malt, in ppm', size=40, w=CW, h=0.9)
bars = [('Glenmorangie', 2, '2 or less', INK), ('Bowmore', 25, 'about 25', INK), ('Caol Ila', 35, 'about 35', INK),
        ('Ardbeg', 55, 'about 55', INK), ('Ardbeg Supernova, 2009', 100, 'over 100', CREAM_MUTE),
        ('Octomore 01.1, 2008', 131, '131', CREAM_MUTE), ('Octomore 08.3, 2017', 309, '309', CREAM_MUTE)]
bx, scale, rh = 4.55, 6.6 / 309, 0.6
yy = 1.95
line(s, X, yy, R, yy, HAIR, 1.0)
for name, v, lab, col in bars:
    text(s, X, yy, 3.6, rh, name, size=17, font=SANS, bold=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    bw = max(v * scale, 0.05)
    rect(s, bx, yy + 0.14, bw, rh - 0.28, fill=col)
    text(s, bx + bw + 0.18, yy, 1.6, rh, lab, size=16, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    yy += rh
    line(s, X, yy, R, yy, HAIR, 1.0)
text(s, X, 6.3, CW, 0.45, 'These are the figures usually published. They vary from batch to batch.',
     size=16, italic=True, color=MUTE)
footer(s, 15)

# ---------------------------------------------------------------- 16 pour 4
pour_slide(16, 'Pour 4 of 4', 'Ardbeg Ten',
           ['The main bottling after the 1997 restart.'],
           'Ardbeg, Islay', 'Islay single malt, 10 years', '46%')

# ---------------------------------------------------------------- 17 reading the label
s = new_slide()
heading(s, 0.85, 'Reading peat on a Scotch label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.95, CW, [
    (['Peated, heavily', 'peated, smoky'], 'No legal definition. The producer’s own description.'),
    ('ppm', 'Measured in the malt. The whisky is lower, by an amount the label does not give.'),
    ('Islay', 'A weak guide. Several Islay distilleries make unpeated whisky.'),
    ('Age statement', 'Smoke fades in the cask. Younger usually tastes smokier.'),
], label_w=3.3, row_h=1.1, label_size=21, size=19)
footer(s, 17)

# ---------------------------------------------------------------- 18 Sláinte
# The old deck's last slide is the logo and the word only; no closing line was written for it.
s = new_slide(INK)
picture(s, LOGO_CREAM, SLIDE_W / 2 - 1.5, 1.0, 3.0, 3.0 * LOGO_RATIO)
text(s, 0.8, 3.65, 11.733, 1.3, 'Sláinte.', size=72, font=SANS, bold=True, color=CREAM,
     align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
rect(s, SLIDE_W / 2 - 0.45, 5.15, 0.9, 0.045, fill=MARK)
text(s, 0.8, 6.55, 11.733, 0.35, 'The Whiskey Share Society', size=11, font=SANS, color=CREAM_MUTE,
     align=PP_ALIGN.CENTER)
