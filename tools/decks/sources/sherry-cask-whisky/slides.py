"""Sherry Cask Whisky: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/sherry-cask-whisky <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (the pilot remake is ../peated-scotch). The photographs are
cropped from that deck's slide images (no other copy was kept); their credits are the old
captions, word for word.
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


def photo_right(s, name, ratio, cap, dark=False):
    """ratio: the crop's height / width, so the frame never stretches it."""
    ph = PW * ratio
    picture(s, A / name, PX, PY, PW, ph, radius_in=0.26)
    credit(s, PX, PY + ph + 0.08, PW, cap, color=CREAM_MUTE if dark else MUTE)


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


def strip(s, y, h, t, size=20):
    """The closing sentence of a slide, in a tinted strip across the content width."""
    rrect(s, X, y, CW, h, r=0.2, fill=W100)
    text(s, X + 0.3, y, CW - 0.6, h, t, size=size, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)


def table_card(s, y, heads, rows, mark_col, label_w=3.0, row_hs=None, size=19):
    """A white card holding a small table: a label column and two named columns.
    mark_col (0 or 1) gets a short orange rule under its name."""
    pad = 0.4
    col_w = (CW - 2 * pad - label_w) / 2
    row_hs = row_hs or [0.85] * len(rows)
    head_h = 0.85
    h = head_h + sum(row_hs) + 0.25
    rrect(s, X, y, CW, h, r=0.26, fill=WHITE, line=HAIR)
    cxs = [X + pad + label_w, X + pad + label_w + col_w]
    for i, name in enumerate(heads):
        text(s, cxs[i], y + 0.25, col_w - 0.3, 0.5, name, size=26, font=SANS, bold=True, color=INK)
        if i == mark_col:
            rect(s, cxs[i] + 0.02, y + 0.8, 0.9, 0.045, fill=MARK)
    yy = y + head_h + 0.1
    for (label, a, b), rh in zip(rows, row_hs):
        line(s, X + pad, yy, X + CW - pad, yy, HAIR, 1.0)
        text(s, X + pad, yy, label_w - 0.2, rh, label, size=18, font=SANS, bold=True, color=MUTE,
             anchor=MSO_ANCHOR.MIDDLE)
        for cx, val in zip(cxs, (a, b)):
            text(s, cx, yy, col_w - 0.3, rh, val, size=size, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)
        yy += rh


def pour_slide(n, pour, name, note, maker, style, abv, two_line_name=False, note_size=21):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / ABV."""
    s = new_slide()
    bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=note_size, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.35, r=0.26, fill=WHITE, line=HAIR)
    cols = [('Maker', maker, 2.55), ('Style', style, 3.35), ('ABV', abv, 1.1)]
    cx = x + 0.3
    for label, val, cw in cols:
        text(s, cx, 4.85, cw, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw, 0.6, val, size=18, color=INK, ls=1.1)
        cx += cw + 0.2
    footer(s, n)
    return s


def two_cards(s, y, h, left, right):
    """A white card and a raised green card side by side. Each side: (name, sub, lines, body).
    lines are hairline-separated rows; body is a paragraph. The green card's name gets a small
    orange rule under it."""
    pw = (CW - 0.25) / 2
    for side, (cx, fill, edge, col, mute) in zip(
            (left, right),
            ((X, WHITE, HAIR, INK, MUTE), (X + pw + 0.25, OAK, OAK_EDGE, CREAM, CREAM_MUTE))):
        name, sub, lines_, body = side
        rrect(s, cx, y, pw, h, r=0.3, fill=fill, line=edge)
        text(s, cx + 0.4, y + 0.25, pw - 0.8, 0.75, name, size=34, font=SANS, bold=True, color=col)
        if fill == OAK:
            rect(s, cx + 0.42, y + 1.0, 0.9, 0.045, fill=MARK)
        yy = y + 1.1
        if sub:
            text(s, cx + 0.4, yy + 0.05, pw - 0.8, 0.45, sub, size=19, font=SANS, bold=True, color=mute)
            yy += 0.7
        for ln in lines_:
            line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
            text(s, cx + 0.4, yy + 0.08, pw - 0.8, 0.6, ln, size=21, color=col, anchor=MSO_ANCHOR.MIDDLE)
            yy += 0.72
        if body:
            text(s, cx + 0.4, yy, pw - 0.8, h - (yy - y) - 0.2, body, size=19, color=col, ls=1.2)


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 3.05, 6.2, 1.0, 'Sherry Cask Whisky', size=44, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.12, 0.9, 0.045, fill=MARK)
text(s, X, 4.35, 6.2, 0.45, 'Sherry casks and Scotch  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 4.95, 5.9, 1.6,
     'How Britain’s taste for a Spanish wine put its casks into Scottish distilleries, and what '
     'distillers did when the casks stopped coming.', size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 5.13
th = tw * 1284 / 1104
picture(s, A / 'wild-spain-bodega-1893.jpg', 7.35, 0.5, tw, th, radius_in=0.26)
credit(s, 7.35, 0.5 + th + 0.08, tw,
       ['Butts being moved in a Spanish wine bodega.', 'Chapman and Buck, Wild Spain, 1893.'], color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 cask sizes
s = new_slide()
heading(s, 0.75, ['Scotch matures in casks that held', 'something else first'], size=40, w=CW, h=1.5)
casks = [('Barrel', 200, 'about 200 litres, from American bourbon', W200),
         ('Hogshead', 250, 'about 250 litres, bourbon barrels rebuilt', W200),
         ('Butt', 500, 'about 500 litres, from the sherry trade', INK)]
rrect(s, X, 2.45, CW, 3.3, r=0.26, fill=WHITE, line=HAIR)
bx, scale, rh = X + 2.85, 8.2 / 500, 1.0
yy = 2.55
for i, (name, litres, cap, col) in enumerate(casks):
    if i:
        line(s, X + 0.3, yy, R - 0.3, yy, HAIR, 1.0)
    if col == INK:
        dot(s, X + 0.16, yy + rh / 2, 0.12, MARK_DEEP)
    text(s, X + 0.3, yy, 2.4, rh, name, size=24, font=SANS, bold=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    rect(s, bx, yy + 0.17, litres * scale, 0.28, fill=col)
    text(s, bx, yy + 0.52, 8.2, 0.4, cap, size=17.5, color=INK)
    yy += rh
text(s, X, 6.05, CW, 0.5, 'By law: at least three years in oak, in Scotland.', size=20, color=INK)
footer(s, 2)

# ---------------------------------------------------------------- 3 Britain
s = new_slide()
heading(s, 0.75, ['Britain was sherry’s', 'biggest customer', 'in the 1800s'], size=36, w=6.6, h=1.9)
rows_card(s, X, 2.85, 6.55, [
    ('Sandeman', 'founded in London, 1790'),
    ('Harvey’s', 'wine merchants of Bristol'),
    ('González Byass', ['Jerez, with an', 'English partner']),
    ('Williams & Humbert', 'Jerez, 1877'),
], label_w=2.75, row_h=0.88, mark=3, label_size=19, size=17)
photo_right(s, 'gonzalez-byass-bodega-1865.jpg', 1232 / 1054,
            'A González Byass bodega in Jerez. El Museo Universal, 1865.')
footer(s, 3)

# ---------------------------------------------------------------- 4 in the cask
s = new_slide()
heading(s, 0.85, 'Sherry crossed to Britain in the cask', size=40, w=CW, h=0.9)
steps = [('Jerez', 'Sherry filled into a new transport butt'),
         ('The voyage', ['To Bristol,', 'London, Liverpool,', 'Leith, Glasgow']),
         ('Merchant', 'Bottles it under his own name'),
         ('Empty butt', ['Sold cheaply', 'to distillers', 'and blenders'])]
gap = 0.22
cw = (CW - 3 * gap) / 4
for i, (t, body) in enumerate(steps):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.1, cw, 3.0, r=0.26, fill=WHITE, line=HAIR)
    if i == 3:
        rect(s, cx + 0.3, 2.35, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.55, cw - 0.6, 0.6, t, size=26, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.3, cw - 0.45, 1.7, body, size=17.5, color=INK, ls=1.2)
strip(s, 5.45, 0.8, 'The old casks in which sherry is aged stayed in the bodegas in Spain.')
footer(s, 4)

# ---------------------------------------------------------------- 5 1915
s = new_slide()
text(s, 0.75, 0.6, 6.6, 1.8, '1915', size=130, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 6.6, 1.3, ['Whisky must spend two years', 'in bond before sale.'], size=32, font=SANS, bold=True,
     color=INK, ls=0.95)
text(s, X, 4.2, 6.5, 2.0,
     'Raised to three years in 1916. Before the war, much Scotch was sold within months of distilling.',
     size=20, color=INK, ls=1.2)
photo_right(s, 'lloyd-george.jpg', 1287 / 1056, 'David Lloyd George. Public domain.')
footer(s, 5)

# ---------------------------------------------------------------- 6 1938
s = new_slide()
heading(s, 0.85, 'From 1938, bourbon goes into new barrels', size=40, w=CW, h=0.9)
rows_card(s, X, 2.1, CW, [
    ('Filled', 'New charred oak, as American law requires.'),
    ('Emptied', 'The barrel cannot hold bourbon again.'),
    ('Sold', 'Much of it to Scottish distillers.'),
], label_w=2.4, row_h=1.15, mark=1, label_size=28, size=22)
footer(s, 6)

# ---------------------------------------------------------------- 7 barrel and butt
# The old slide had no heading of its own; it takes the script's.
s = new_slide()
heading(s, 0.85, 'An ex-bourbon barrel and a sherry butt', size=40, w=CW, h=0.9)
two_cards(s, 2.0, 4.45,
          ('Ex-bourbon barrel', None,
           ['American white oak', 'About 200 litres, charred', 'Pale gold colour', 'Vanilla, coconut, honey'], None),
          ('Sherry butt', None,
           ['European or American oak', 'About 500 litres, toasted', 'Darker colour', 'Dried fruit, nuts, tannin'], None))
footer(s, 7)

# ---------------------------------------------------------------- 8 pour 1
pour_slide(8, 'Pour 1 of 4', ['Glenmorangie', 'The Original'],
           ['Matured only in ex-bourbon casks.', 'Keep a little in your glass to come back to.'],
           'Glenmorangie, Tain', 'Single malt, 12 years', '40%', two_line_name=True)

# ---------------------------------------------------------------- 9 1981–1986 (the green story slide)
s = new_slide(INK)
text(s, X, 0.8, CW, 0.6, 'Sherry must be bottled in the Jerez region', size=28, font=SANS, bold=True, color=CREAM)
text(s, 0.75, 1.55, CW, 1.8, '1981–1986', size=120, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 3.45, 1.2, 0.045, fill=MARK)
text(s, X, 3.75, 10.5, 2.6, [
    'Bulk shipments in cask end, and with them the supply of transport butts to Britain.',
    [('The sherry regulator dates its rule to the early 1980s. Other sources give 1986, when Spain joined '
      'the European Community.', {'color': CREAM_MUTE, 'size': 19})],
], size=24, color=CREAM, ls=1.2, space_after=14)
footer(s, 9, dark=True)

# ---------------------------------------------------------------- 10 two ways
s = new_slide()
heading(s, 0.85, 'Two ways round the shortage', size=40, w=CW, h=0.9)
two_cards(s, 2.0, 3.35,
          ('Finish', 'Glenmorangie, 1990s',
           [], ['Mature in ex-bourbon barrels, then', 'move the whisky into a sherry cask', 'for its last part.']),
          ('Seasoned cask', 'Macallan',
           [], 'Have casks built in Jerez and filled with sherry to order, then mature in them from the start.'))
strip(s, 5.6, 0.95, ['A finish needs far fewer sherry casks per bottle.',
                    'Seasoned casks let a distillery keep full sherry maturation.'], size=19)
footer(s, 10)

# ---------------------------------------------------------------- 11 pour 2
pour_slide(11, 'Pour 2 of 4', ['Glenmorangie', 'Lasanta'],
           ['The same distillery and age as pour one, with its last two years in oloroso and Pedro Ximénez casks.',
            'Taste the two side by side.'],
           'Glenmorangie, Tain', 'Single malt, 12 years', '43%', two_line_name=True, note_size=19)

# ---------------------------------------------------------------- 12 seasoned casks
s = new_slide()
heading(s, 0.85, 'Seasoned casks, made to order in Jerez', size=40, w=CW, h=0.9)
rows_card(s, X, 2.1, CW, [
    ('Cooperage', 'Builds a new cask from the oak the distiller chooses.'),
    ('Bodega', 'Fills it with sherry, usually for a year or more.'),
    ('Distillery', 'Receives the emptied cask and fills it with new spirit.'),
], label_w=2.6, row_h=1.05, mark=1, label_size=26, size=21)
strip(s, 5.6, 0.95, 'Since 2015 the sherry regulator certifies a “Sherry Cask”: seasoned for at least twelve months '
                    'with sherry from the region.', size=19)
footer(s, 12)

# ---------------------------------------------------------------- 13 solera and seasoned
s = new_slide()
heading(s, 0.85, 'A solera cask and a seasoned cask', size=40, w=CW, h=0.9)
table_card(s, 2.0, ['Solera cask', 'Seasoned cask'], [
    ('Made for', 'Ageing sherry in a bodega', 'Selling to a distiller'),
    ('Holds sherry', 'For decades', 'Usually one to two years'),
    ('Oak left to give', 'Little', 'Plenty'),
    ('In Scotch today', 'Rare', 'Nearly every sherry cask'),
], mark_col=1, label_w=3.0, row_hs=[0.82] * 4, size=20)
footer(s, 13)

# ---------------------------------------------------------------- 14 pour 3
pour_slide(14, 'Pour 3 of 4', ['Macallan 12', 'Sherry Oak'],
           ['Matured in sherry-seasoned oak casks', 'from Jerez, mostly European oak.',
            'Compare it with the Lasanta.'],
           'Macallan, Speyside', 'Single malt, 12 years', '43%', two_line_name=True, note_size=20)

# ---------------------------------------------------------------- 15 oloroso and PX
s = new_slide()
heading(s, 0.85, 'Oloroso and Pedro Ximénez', size=40, w=CW, h=0.9)
table_card(s, 2.0, ['Oloroso', 'Pedro Ximénez'], [
    ('Grape', 'Palomino', 'Pedro Ximénez'),
    ('Made', 'Fermented dry, fortified, aged in contact with air', 'From grapes dried in the sun until nearly raisins'),
    ('In the glass', 'Brown, nutty, dry', 'Almost black, thick, very sweet'),
], mark_col=1, label_w=2.6, row_hs=[0.85, 1.25, 0.85], size=20)
footer(s, 15)

# ---------------------------------------------------------------- 16 GlenDronach
s = new_slide()
heading(s, 0.85, 'GlenDronach, 1826 to now', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('1826', 'Founded near Forgue by James Allardice.'),
    ('1960', 'Bought by Teacher’s, for its blend.'),
    ('1996', 'Closed by Allied. Reopened 2002.'),
    ('2008', 'Billy Walker buys it and turns to sherry casks.'),
    ('2016', 'Sold to Brown-Forman of Kentucky.'),
], label_w=1.5, row_h=0.66, mark=3, label_size=26, size=19)
strip(s, 5.45, 0.8, 'Since 2008 GlenDronach has been sold as a sherry-cask whisky.')
footer(s, 16)

# ---------------------------------------------------------------- 17 pour 4
pour_slide(17, 'Pour 4 of 4', 'GlenDronach 12',
           ['Matured in Pedro Ximénez and oloroso casks.', 'Put it beside the Macallan.'],
           'GlenDronach, Forgue', 'Single malt, 12 years', '43%')

# ---------------------------------------------------------------- 18 reading the label
s = new_slide()
heading(s, 0.85, 'Reading the cask on a Scotch label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('Ex-bourbon', 'Barrels that held American whiskey.'),
    ('Sherry cask, sherry oak', 'Almost always a seasoned cask. European or American oak.'),
    ('Matured in / finished in', 'All or most of its life, or only the last part.'),
    ('Oloroso, PX', 'The sherry that seasoned the cask.'),
    ('Natural colour', 'No caramel added. Without it, the colour may be partly caramel.'),
], label_w=3.25, row_h=0.9, label_size=20, size=18)
footer(s, 18)

# ---------------------------------------------------------------- 19 Sláinte
# The old deck's last slide is the logo and the word only; no closing line was written for it.
s = new_slide(INK)
picture(s, LOGO_CREAM, SLIDE_W / 2 - 1.5, 1.0, 3.0, 3.0 * LOGO_RATIO)
text(s, 0.8, 3.65, 11.733, 1.3, 'Sláinte.', size=72, font=SANS, bold=True, color=CREAM,
     align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
rect(s, SLIDE_W / 2 - 0.45, 5.15, 0.9, 0.045, fill=MARK)
text(s, 0.8, 6.55, 11.733, 0.35, 'The Whiskey Share Society', size=11, font=SANS, color=CREAM_MUTE,
     align=PP_ALIGN.CENTER)
