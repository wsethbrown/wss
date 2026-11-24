"""Blended Scotch: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/blended-scotch <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
pictures, laid out with the house kit. The pictures are cropped from that deck's slide images
(no other copy was kept); their credits are the old captions, word for word.
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


def big_year(s, year, y=1.15):
    """The paper history slide's year: 150 pt in green, a short orange rule under it."""
    text(s, 0.75, y, 7.0, 2.1, year, size=150, font=SANS, bold=True, color=INK, ls=0.9)
    rect(s, X + 0.03, y + 2.2, 1.2, 0.045, fill=MARK_DEEP)


def pour_slide(n, pour, name, note, maker, style, abv, two_line_name=False, widths=(2.75, 3.15, 1.1), val_size=18,
               photo=None, credit=None):
    """One pour: the bottle's photograph (or the placeholder card when there is none), the pour
    line, the name, the old slide's note, and Maker / Style / ABV."""
    s = new_slide()
    bottle_panel(s, photo, X, 0.8, 3.4, 5.3, credit)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=21, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.35, r=0.26, fill=WHITE, line=HAIR)
    cols = [('Maker', maker, widths[0]), ('Style', style, widths[1]), ('ABV', abv, widths[2])]
    cx = x + 0.3
    for label, val, cw in cols:
        text(s, cx, 4.85, cw, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw, 0.6, val, size=val_size, color=INK, ls=1.1)
        cx += cw + 0.2
    footer(s, n)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 3.0, 6.5, 1.0, 'Blended Scotch', size=52, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.12, 0.9, 0.045, fill=MARK)
text(s, X, 4.35, 6.2, 0.45, '1830 to 1910  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 4.95, 5.9, 1.5,
     'How Scotch went from casks of malt whisky to blends sold around the world.',
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 5.0
th = tw * 1287 / 1104
picture(s, A / 'landseer-illicit-highland-whisky-still-1829.jpg', 7.48, 0.55, tw, th, radius_in=0.26)
credit(s, 7.48, 0.55 + th + 0.08, tw,
       'Edwin Landseer, The Illicit Highland Whisky Still, 1829. Apsley House, London.', color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 Scotch in 1830
s = new_slide()
heading(s, 0.85, 'Scotch in 1830: malt, sold by the cask', size=40, w=CW, h=0.9)
rows_card(s, X, 2.1, CW, [
    ('Distiller', 'malted barley, a pot still, one batch at a time'),
    ('Merchant', 'buys by the cask: grocer, innkeeper, wine merchant'),
    ('Your glass', 'changes from cask to cask'),
], label_w=2.6, row_h=1.15, mark=2, label_size=26, size=22)
footer(s, 2)

# ---------------------------------------------------------------- 3 1830, Coffey's still
s = new_slide()
big_year(s, '1830', y=0.75)
text(s, X, 3.25, 5.7, 1.0, 'Aeneas Coffey patents a continuous still.', size=28, font=SANS, bold=True,
     color=INK, ls=0.95)
text(s, X, 4.35, 5.6, 1.5,
     'Steam strips the alcohol from the wash in one column, and the second column concentrates it. '
     'It runs for as long as it is fed.', size=18, color=INK, ls=1.2)
text(s, X, 5.75, 5.7, 0.8, ['Coffey had been Inspector-General of Excise', 'in Ireland until 1824.'],
     size=16, color=MUTE, ls=1.15)
# The still, drawn: two columns, the vapour crossing from the analyser to the rectifier.
cx1, cx2, cwid, cy, ch = 6.8, 9.98, 2.5, 1.5, 2.65
for cx, name, body in [(cx1, 'Analyser', ['Wash falls through', 'perforated plates.', 'Rising steam carries', 'the alcohol up.']),
                       (cx2, 'Rectifier', ['The vapour is', 'concentrated.', 'Spirit is drawn off', 'near the top.'])]:
    rrect(s, cx, cy, cwid, ch, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.28, cy + 0.25, cwid - 0.5, 0.5, name, size=24, font=SANS, bold=True, color=INK)
    text(s, cx + 0.28, cy + 0.9, cwid - 0.4, 2.2, body, size=16, color=INK, ls=1.25)
rect(s, cx1 + 0.28, cy + 0.12, 0.9, 0.045, fill=MARK_DEEP)
text(s, cx1 + cwid - 0.2, cy + 0.3, cx2 - cx1 - cwid + 0.4, 0.35, 'vapour', size=13, font=SANS, bold=True, color=INK,
     align=PP_ALIGN.CENTER)
text(s, cx1 + cwid, cy + 0.62, cx2 - cx1 - cwid, 0.4, '→', size=22, font=SANS, bold=True, color=MARK_DEEP,
     align=PP_ALIGN.CENTER)
text(s, cx1, cy + ch + 0.15, cwid, 0.4, '↑ steam in', size=16, color=MUTE)
text(s, cx2, cy + ch + 0.15, cwid, 1.3, 'wash in, warmed in the rectifier, then piped to the top of the analyser',
     size=16, color=MUTE, ls=1.15)
footer(s, 3)

# ---------------------------------------------------------------- 4 pour 1
pour_slide(4, 'Pour 1 of 4', 'Haig Club Clubman',
           ['Grain whisky on its own.', 'Most grain whisky goes into blends.'],
           'Diageo, Cameronbridge, Fife', 'Single grain Scotch whisky', '40%',
           widths=(3.2, 2.95, 0.6), val_size=16.5,
           photo='haig-club-clubman.jpg', credit='Photograph: arw49, CC BY 2.0, via Flickr. Cropped.')

# ---------------------------------------------------------------- 5 malt and grain
s = new_slide()
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, 'Malt whisky',
          ['Pot still, batch by batch', 'Malted barley only',
           [('Heavy, and ', {}), ('varied', {'bold': True})]]),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Grain whisky',
          ['Coffey still, continuous', 'Mostly unmalted grain',
           [('Light, and ', {}), ('cheap', {'bold': True})]])]
for (cx, fill, edge, col, name, lines_) in sides:
    rrect(s, cx, 0.85, pw, 5.6, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.45, 1.25, pw - 0.9, 0.9, name, size=44, font=SANS, bold=True, color=col)
    yy = 2.65
    for ln in lines_:
        line(s, cx + 0.45, yy, cx + pw - 0.45, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.45, yy + 0.1, pw - 0.9, 0.9, [ln], size=25, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 1.1
rect(s, X + pw + 0.25 + 0.47, 2.3, 0.9, 0.045, fill=MARK)
footer(s, 5)

# ---------------------------------------------------------------- 6 Usher
s = new_slide()
heading(s, 0.85, 'Andrew Usher vats Glenlivet, 1853', size=40, w=CW, h=0.9)
op = 0.6
c1 = 3.05
c3 = CW - 2 * c1 - 2 * op
boxes = [(X, c1, 'Glenlivet', 'younger casks'),
         (X + c1 + op, c1, 'Glenlivet', 'older casks'),
         (X + 2 * c1 + 2 * op, c3, 'Old Vatted Glenlivet', 'the same from bottle to bottle')]
for i, (bx, bw, t, sub) in enumerate(boxes):
    rrect(s, bx, 2.1, bw, 2.2, r=0.26, fill=WHITE, line=HAIR)
    if i == 2:
        rect(s, bx + 0.35, 2.35, 0.9, 0.045, fill=MARK_DEEP)
    text(s, bx + 0.35, 2.6, bw - 0.6, 0.6, t, size=26, font=SANS, bold=True, color=INK)
    text(s, bx + 0.35, 3.3, bw - 0.6, 0.9, sub, size=20, color=INK, ls=1.15)
for i, sym in enumerate(['+', '=']):
    ox = X + (i + 1) * c1 + i * op
    text(s, ox, 2.1, op, 2.2, sym, size=34, font=SANS, bold=True, color=INK, align=PP_ALIGN.CENTER,
         anchor=MSO_ANCHOR.MIDDLE)
rrect(s, X, 4.75, CW, 1.5, r=0.2, fill=W100)
text(s, X + 0.35, 4.75, CW - 0.7, 1.5,
     'The Ushers were Smith’s agents in Edinburgh. A change in the law in 1853 allowed whiskies from '
     'one distillery to be vatted together.', size=21, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.2)
footer(s, 6)

# ---------------------------------------------------------------- 7 pour 2
pour_slide(7, 'Pour 2 of 4', ['The Glenlivet', '12 Year Old'],
           ['The malt Usher vatted.', 'Heavier than the grain whisky,', 'with more fruit and cereal.'],
           'Chivas Brothers, Speyside', 'Single malt Scotch whisky', '40%', two_line_name=True,
           photo='glenlivet-12.jpg',
           credit='Pictured: an older label, on a litre bottle. Photograph: ChickenFalls, CC BY-SA 3.0, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 8 1860, the Spirits Act
s = new_slide()
kicker(s, 'The Spirits Act')
big_year(s, '1860', y=1.2)
ew, eo, ey, eh = 2.7, 0.6, 3.85, 1.05
eq = [(X, WHITE, HAIR, INK, 'Malt'), (X + ew + eo, WHITE, HAIR, INK, 'Grain'),
      (X + 2 * (ew + eo), OAK, OAK_EDGE, CREAM, 'Blend')]
for (bx, fill, edge, col, t) in eq:
    rrect(s, bx, ey, ew, eh, r=0.22, fill=fill, line=edge)
    text(s, bx, ey, ew, eh, t, size=30, font=SANS, bold=True, color=col, align=PP_ALIGN.CENTER,
         anchor=MSO_ANCHOR.MIDDLE)
rect(s, X + 2 * (ew + eo) + 0.3, ey + 0.16, 0.9, 0.045, fill=MARK)
for i, sym in enumerate(['+', '=']):
    text(s, X + (i + 1) * ew + i * eo, ey, eo, eh, sym, size=30, font=SANS, bold=True, color=INK,
         align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
text(s, X, 5.15, CW, 0.5, 'from different distilleries, mixed in bond before duty is paid', size=23, color=INK)
text(s, X, 5.85, CW, 0.5, 'Passed while W. E. Gladstone was Chancellor of the Exchequer.', size=18, color=MUTE)
footer(s, 8)

# ---------------------------------------------------------------- 9 the grocers
s = new_slide()
heading(s, 0.85, 'The first big blenders were grocers', size=40, w=CW, h=0.9)
rows_card(s, X, 1.95, CW, [
    ('John Walker', 'Grocer in Kilmarnock from 1820'),
    ('George Ballantine', 'Grocer in Edinburgh from 1827'),
    ('James Chivas', 'Grocer on King Street, Aberdeen, from 1838'),
    ('John Dewar', 'Wine and spirit merchant in Perth from 1846'),
], label_w=3.6, row_h=0.85, label_size=22, size=20)
rrect(s, X, 5.6, CW, 0.85, r=0.2, fill=W100)
text(s, X + 0.35, 5.6, CW - 0.7, 0.85,
     'They already bought whisky by the cask, and had shops and regular customers.',
     size=20, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 9)

# ---------------------------------------------------------------- 10 pour 3
pour_slide(10, 'Pour 3 of 4', ['Johnnie Walker', 'Black Label'],
           'Malt and grain together.',
           'Diageo, Scotland', 'Blended Scotch, 12 years', '40%', two_line_name=True,
           photo='johnnie-walker-black.jpg', credit='Photograph: Marcelo Verfe, via Pexels. Cropped.')

# ---------------------------------------------------------------- 11 1860s phylloxera (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 6.6, 1.8, '1860s', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 6.5, 1.2, ['Phylloxera reaches the', 'vineyards of France.'], size=32, font=SANS, bold=True,
     color=CREAM, ls=0.95)
text(s, X, 4.15, 6.4, 2.3,
     'An aphid from North America killed the vines at the roots. It reached Cognac in 1872, and by the '
     '1880s most of the vineyards there were gone.', size=19, color=CREAM, ls=1.25)
ph = PW * 1287 / 1056
picture(s, A / 'punch-phylloxera-gourmet-1890.jpg', PX, 0.6, PW, ph, radius_in=0.26)
credit(s, PX, 0.6 + ph + 0.08, PW, '“The Phylloxera, a true gourmet”. Punch, 6 September 1890.', color=CREAM_MUTE)
footer(s, 11, dark=True)

# ---------------------------------------------------------------- 12 brandy and soda
s = new_slide()
heading(s, 0.85, 'From brandy and soda to whisky and soda', size=40, w=CW, h=0.9)
gap = 0.22
cw = (CW - 3 * gap) / 4
cols = [('1860s', 'Vines start dying in southern France.'),
        ('1872', 'Phylloxera reaches Cognac.'),
        ('1880s', 'Brandy is scarce and dear in England. Blends with soda take its place.'),
        ('1887–98', 'New distilleries, from Glenfiddich (1887) to Aberfeldy (1898).')]
for i, (yr, body) in enumerate(cols):
    cx = X + i * (cw + gap)
    rrect(s, cx, 1.95, cw, 3.4, r=0.26, fill=WHITE, line=HAIR)
    if i >= 2:
        rect(s, cx + 0.3, 2.2, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.4, cw - 0.5, 0.75, yr, size=36, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.25, cw - 0.45, 2.0, body, size=17, color=INK, ls=1.2)
rrect(s, X, 5.6, CW, 0.85, r=0.2, fill=W100)
text(s, X + 0.35, 5.6, CW - 0.7, 0.85,
     'Britain already drank far more whisky than brandy in 1860, before the shortage.',
     size=20, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 12)

# ---------------------------------------------------------------- 13 the salesmen
s = new_slide()
heading(s, 0.85, 'The salesmen of the 1890s', size=40, w=CW, h=0.9)
hw = (CW - 0.5) / 2
hh = hw * 437 / 980
people = [(X, 'thomas-dewar-bain-news-service.jpg', 'Thomas Dewar. Bain News Service, Library of Congress.',
           'Tommy Dewar, 1864–1930',
           'In London from 1885. Toured the world for the firm. His book about it came out in 1894.'),
          (X + hw + 0.5, 'james-buchanan-spy-vanity-fair-1907.jpg',
           'Buchanan by Spy, Vanity Fair, 1907: “Whisky and Horses”.',
           'James Buchanan, 1849–1935',
           ['Supplied the House of Commons from 1885.', 'The blend became Black & White.'])]
for (px, img, cap, name, body) in people:
    picture(s, A / img, px, 1.85, hw, hh, radius_in=0.22)
    credit(s, px, 1.85 + hh + 0.08, hw, cap)
    text(s, px, 1.85 + hh + 0.5, hw, 0.5, name, size=24, font=SANS, bold=True, color=INK)
    text(s, px, 1.85 + hh + 1.05, hw, 1.0, body, size=18, color=INK, ls=1.2)
footer(s, 13)

# ---------------------------------------------------------------- 14 pour 4
pour_slide(14, 'Pour 4 of 4', ['Dewar’s', 'White Label'],
           'In the 1890s London drank it in a tall glass with ice and soda water.',
           'John Dewar & Sons, Perth', 'Blended Scotch whisky', '40%', two_line_name=True,
           widths=(3.35, 2.6, 0.9),
           photo='dewars-white-label.jpg',
           credit='Pictured: an older label. Photograph: Nfutvol, CC BY-SA 3.0, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 15 1898, Pattisons
s = new_slide()
kicker(s, 'Pattisons of Leith fails')
big_year(s, '1898', y=1.2)
text(s, X, 3.85, 10.6, 1.4,
     'In December the blenders Robert and Walter Pattison went under. In 1901 both were convicted of '
     'fraud: Robert got 18 months, Walter 9.', size=24, color=INK, ls=1.2)
text(s, X, 5.4, 10.6, 0.6, 'Lenders grew wary of the whisky trade, and the boom of the 1890s was over.',
     size=19, color=MUTE)
footer(s, 15)

# ---------------------------------------------------------------- 16 the Royal Commission
s = new_slide()
jh = 5.55
jw = jh * 816 / 1257
jx = R - jw
heading(s, 0.75, ['1908–09: a Royal Commission', 'decides what whisky is'], size=36, w=jx - X - 0.4, h=1.3)
rows_card(s, X, 2.35, jx - X - 0.45, [
    ('Malt distillers', 'Only pot-still spirit is whisky.'),
    (['Blenders, grain', 'distillers'], 'Any spirit from a grain mash is whisky.'),
    ('The report, 1909', 'Grain mash, converted by malt. Any still.'),
], label_w=2.55, row_h=1.15, mark=2, label_size=19, size=19)
picture(s, A / 'henry-james-ape-vanity-fair-1874.jpg', jx, 0.75, jw, jh, radius_in=0.26)
credit(s, jx, 0.75 + jh + 0.08, jw,
       'Sir Henry James, later Lord James of Hereford, the chairman. Ape, Vanity Fair, 7 March 1874.')
footer(s, 16)

# ---------------------------------------------------------------- 17 reading the label
s = new_slide()
heading(s, 0.85, 'Reading a Scotch label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('Single malt', 'One distillery. Malted barley only, pot stills.'),
    ('Single grain', 'One distillery. Other cereals and column stills allowed.'),
    ('Blended malt', 'Single malts from several distilleries. No grain.'),
    ('Blended Scotch', 'Malt and grain whiskies mixed.'),
    ('Age statement', 'The age of the youngest whisky in the bottle.'),
], label_w=3.0, row_h=0.8, label_size=21, size=19)
text(s, X, 6.2, CW, 0.45, 'All Scotch: at least three years in oak, in Scotland.', size=17, italic=True, color=MUTE)
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
