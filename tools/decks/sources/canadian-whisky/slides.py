"""Canadian Whisky: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/canadian-whisky <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (the Peat Reek and Rye Country remakes are the models).
The photographs are cropped from that deck's slide images (no other copy was kept); their
credits are the old captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PY = 0.75                # top of a right-hand photo


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, px_w, px_h, cap, h=5.5, dark=False):
    """A photo at a fixed height, its width from the crop's own ratio, right-aligned on R."""
    w = h * px_w / px_h
    x = R - w
    picture(s, A / name, x, PY, w, h, radius_in=0.26)
    credit(s, x, PY + h + 0.08, w, cap, color=CREAM_MUTE if dark else MUTE)
    return x


def panorama(s, name, y, cap, px_w=2060, px_h=419):
    """A wide photo across the content width, credit under it."""
    h = CW * px_h / px_w
    picture(s, A / name, X, y, CW, h, radius_in=0.2)
    credit(s, X, y + h + 0.08, CW, cap)


def rows_card(s, x, y, w, items, label_w, row_h, mark=None, label_size=20, size=17.5, pad=0.3):
    """A white hairline card of label / text rows. row_h: one height, or one per row.
    mark: index of the row to mark with an orange dot."""
    hs = row_h if isinstance(row_h, (list, tuple)) else [row_h] * len(items)
    rrect(s, x, y, w, sum(hs) + 0.1, r=0.26, fill=WHITE, line=HAIR)
    yy = y + 0.05
    for i, ((label, val), rh) in enumerate(zip(items, hs)):
        if i:
            line(s, x + pad, yy, x + w - pad, yy, HAIR, 1.0)
        if i == mark:
            dot(s, x + 0.16, yy + rh / 2, 0.12, MARK_DEEP)
        text(s, x + pad, yy, label_w, rh, label, size=label_size, font=SANS, bold=True, color=INK,
             anchor=MSO_ANCHOR.MIDDLE, ls=0.95)
        text(s, x + pad + label_w + 0.25, yy, w - 2 * pad - label_w - 0.25, rh, val, size=size, color=INK,
             anchor=MSO_ANCHOR.MIDDLE, ls=1.15)
        yy += rh


def strip(s, y, h, t, size=19):
    """A closing sentence in a light band across the content width."""
    rrect(s, X, y, CW, h, r=0.2, fill=W100)
    text(s, X + 0.3, y, CW - 0.6, h, t, size=size, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)


def pour_slide(n, pour, name, note, maker, style, abv, two_line_name=False, widths=(2.75, 3.15, 1.1),
               val_size=18):
    """One pour: a bottle-shaped placeholder card (no photograph of any of the four bottles was in
    the old deck), the pour line, the name, the old slide's note, and Maker / Style / ABV."""
    s = new_slide()
    bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=21, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.5, r=0.26, fill=WHITE, line=HAIR)
    cx = x + 0.3
    for label, val, cw_ in zip(('Maker', 'Style', 'ABV'), (maker, style, abv), widths):
        text(s, cx, 4.85, cw_, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw_, 0.8, val, size=val_size, color=INK, ls=1.1)
        cx += cw_ + 0.2
    footer(s, n)
    return s


def big_figure(n, head, figure, body, quiet, quiet_y=5.2, head_size=32):
    """A big-figure slide on paper: the old slide's heading, the figure in green at 150 pt with a
    short orange rule under it, the sentence and the quieter line under that."""
    s = new_slide()
    heading(s, 0.75, head, size=head_size, w=CW, h=0.7)
    text(s, 0.75, 1.45, 9.0, 2.1, figure, size=150, font=SANS, bold=True, color=INK, ls=0.9)
    rect(s, X + 0.03, 3.65, 1.2, 0.045, fill=MARK_DEEP)
    text(s, X, 3.95, 10.4, 1.0, body, size=24, color=INK, ls=1.2)
    text(s, X, quiet_y, 10.4, 1.0, quiet, size=19, color=MUTE, ls=1.2)
    footer(s, n)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 2.95, 6.5, 1.0, 'Canadian Whisky', size=52, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.12, 0.9, 0.045, fill=MARK)
text(s, X, 4.35, 6.2, 0.45, 'Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 4.95, 5.9, 1.5,
     'How Canadian whisky is made, and how it came to supply the United States.',
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 5.13
th = tw * 874 / 1104
picture(s, A / 'walkerville-from-detroit-river.jpg', 7.35, 1.2, tw, th, radius_in=0.26)
credit(s, 7.35, 1.2 + th + 0.08, tw,
       ['Walker’s distillery at Walkerville, seen from the Detroit River, about 1905–1915.',
        'Detroit Publishing Co., Library of Congress.'], color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 five distillers
s = new_slide()
heading(s, 0.75, 'Five Ontario distillers, 1837 to 1864', size=40, w=CW, h=0.9)
founders = [('1837', ['Gooderham', '& Worts'], 'Toronto'),
            ('1857', 'J.P. Wiser', 'Prescott'),
            ('1858', 'Hiram Walker', 'Windsor'),
            ('1859', 'Henry Corby', 'Corbyville'),
            ('1864', 'Joseph Seagram', 'Waterloo')]
g5 = 0.2
c5 = (CW - 4 * g5) / 5
for i, (yr, name, place) in enumerate(founders):
    cx = X + i * (c5 + g5)
    rrect(s, cx, 1.75, c5, 1.95, r=0.22, fill=WHITE, line=HAIR)
    text(s, cx + 0.25, 1.9, c5 - 0.5, 0.6, yr, size=30, font=SANS, bold=True, color=INK)
    text(s, cx + 0.25, 2.55, c5 - 0.4, 0.75, name, size=16, font=SANS, bold=True, color=INK, ls=0.95)
    text(s, cx + 0.25, 3.2, c5 - 0.4, 0.4, place, size=16, color=MUTE)
panorama(s, 'gooderham-worts-hider-1896.jpg', 3.95,
         'Gooderham & Worts on the Toronto waterfront, painted by A.H. Hider, about 1896. Library and Archives Canada.')
footer(s, 2)

# ---------------------------------------------------------------- 3 1858 (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 6.4, 1.8, '1858', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 6.9, 1.6, ['Hiram Walker, a Detroit grain', 'merchant, starts distilling', 'across the river.'],
     size=28, font=SANS, bold=True, color=CREAM, ls=0.98)
text(s, X, 4.5, 6.6, 1.6,
     'He built a company town around the distillery. It was called Walkerville and is now part of '
     'Windsor,\u00a0Ontario.', size=18.5, color=CREAM, ls=1.2)
photo_right(s, 'hiram-walker-portrait.jpg', 960, 1284,
            'Hiram Walker (1816–1899). Hiram Walker & Sons archive, CC0.', dark=True)
footer(s, 3, dark=True)

# ---------------------------------------------------------------- 4 the Civil War tax
s = new_slide()
heading(s, 0.75, 'The US whiskey tax, raised to pay for the Civil War', size=34, w=CW, h=0.9)
rates = [('20¢', 'August 1862'), ('60¢', 'March 1864'), ('$1.50', 'July 1864'),
         ('$2', ['January 1865', 'to July 1868'])]
gap = 0.22
cw = (CW - 3 * gap) / 4
for i, (big, when) in enumerate(rates):
    cx = X + i * (cw + gap)
    rrect(s, cx, 1.8, cw, 2.75, r=0.26, fill=WHITE, line=HAIR)
    if i == 3:
        rect(s, cx + 0.3, 2.05, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.2, cw - 0.55, 1.1, big, size=52, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.3, 3.35, cw - 0.5, 1.1, when, size=19, color=INK, ls=1.2)
strip(s, 4.95, 1.0, ['Federal excise on a proof gallon of spirits.',
                   'Walker’s distillery was a short ferry ride from Detroit.'], size=20)
footer(s, 4)

# ---------------------------------------------------------------- 5 pour 1
pour_slide(5, 'Pour 1 of 4', 'Canadian Club 1858',
           ['Walker’s brand, still made in Walkerville.'],
           'Hiram Walker & Sons, Windsor, Ontario', 'Blended Canadian whisky', '40%',
           widths=(3.0, 2.95, 0.85))

# ---------------------------------------------------------------- 6 1890
big_figure(6, 'Canada requires two years in wood', '1890',
           'A rule first set in 1887 came fully into force: whisky had to spend two years in wood before '
           'sale. The minimum is now\u00a0three.',
           'The United States had no minimum age for whiskey then. Its bonded act of 1897 was\u00a0voluntary.')

# ---------------------------------------------------------------- 7 each grain on its own
s = new_slide()
heading(s, 0.75, 'Each grain is distilled and aged on its own', size=38, w=CW, h=0.9)
tw7 = 8.3
grains = [('Corn', 'column still, high strength', 'base whisky'),
          ('Wheat', 'column still, high strength', 'base whisky'),
          ('Rye', ['lower strength,', 'column or pot'], 'flavouring whisky'),
          ('Barley', 'lower strength', 'flavouring whisky')]
rh7 = 0.85
rrect(s, X, 1.8, tw7, rh7 * 4 + 0.1, r=0.26, fill=WHITE, line=HAIR)
yy = 1.85
for i, (g, still, kind) in enumerate(grains):
    if i:
        line(s, X + 0.3, yy, X + tw7 - 0.3, yy, HAIR, 1.0)
    text(s, X + 0.3, yy, 1.2, rh7, g, size=22, font=SANS, bold=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    text(s, X + 1.55, yy, 2.85, rh7, still, size=17, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.1)
    text(s, X + 4.5, yy, 1.45, rh7, 'barrel, years', size=17, color=MUTE, anchor=MSO_ANCHOR.MIDDLE)
    text(s, X + 6.05, yy, 2.0, rh7, kind, size=16, font=SANS, bold=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    yy += rh7
gx = X + tw7 + 0.25
gw = R - gx
rrect(s, gx, 1.8, gw, rh7 * 4 + 0.1, r=0.3, fill=OAK, line=OAK_EDGE)
rect(s, gx + 0.4, 2.85, 0.9, 0.045, fill=MARK)
text(s, gx + 0.4, 3.05, gw - 0.6, 1.4, ['Blended', 'after ageing'], size=28, font=SANS, bold=True,
     color=CREAM, ls=0.95)
strip(s, 5.55, 0.9, 'Bourbon is made from a mixed mash in one run. Canadian distillers usually keep the grains '
                    'apart until the\u00a0end.', size=19)
footer(s, 7)

# ---------------------------------------------------------------- 8 base and flavouring
# The old slide's two column titles are its heading; no heading is added (the script's heading
# names both).
s = new_slide()
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, 'Base whisky',
          ['Usually corn', 'Distilled close to neutral', 'Often aged in used barrels', 'Most of the bottle']),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Flavouring whisky',
          ['Usually rye', 'Distilled to a lower strength', 'Keeps more taste of the grain', 'A smaller share'])]
for (cx, fill, edge, col, name, lines_) in sides:
    rrect(s, cx, 0.8, pw, 5.6, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.45, 1.15, pw - 0.6, 0.85, name, size=38, font=SANS, bold=True, color=col)
    if fill == OAK:
        rect(s, cx + 0.47, 2.05, 0.9, 0.045, fill=MARK)
    yy = 2.4
    for ln in lines_:
        line(s, cx + 0.45, yy, cx + pw - 0.45, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.45, yy + 0.08, pw - 0.9, 0.75, ln, size=24, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 0.92
footer(s, 8)

# ---------------------------------------------------------------- 9 pour 2
pour_slide(9, 'Pour 2 of 4', 'Lot No. 40',
           ['All rye, from a single copper pot still.',
            'This is close to what a flavouring whisky tastes like before it is\u00a0blended.'],
           ['Corby, at the Hiram Walker', 'distillery, Windsor'], ['Canadian rye whisky,', '100% rye'], '43%',
           widths=(3.35, 2.6, 0.85))

# ---------------------------------------------------------------- 10 Prohibition (paper)
s = new_slide()
heading(s, 0.75, ['The US goes dry. Canadian', 'distilleries keep making', 'whisky for export.'],
        size=34, w=6.7, h=1.8)
rows_card(s, X, 2.85, 6.7, [
    ('1920', 'National Prohibition begins in the\u00a0US.'),
    ('1930', 'Canada amends its Export Act and stops clearing liquor shipments to the\u00a0US.'),
    ('1933', 'Repeal.'),
], label_w=1.05, row_h=[0.85, 1.25, 0.85], mark=2, label_size=26, size=18)
photo_right(s, 'detroit-police-prohibition.jpg', 1056, 1254,
            'Detroit police with equipment from an illegal brewery, Prohibition era. National Archives.')
footer(s, 10)

# ---------------------------------------------------------------- 11 Bronfman and Seagram
s = new_slide()
heading(s, 0.75, 'Sam Bronfman builds Seagram, 1924 to 1939', size=36, w=CW, h=0.9)
events = [('1924', ['Distillers Corporation', 'opens at LaSalle,', 'near Montreal.']),
          ('1928', 'It buys Joseph E. Seagram\u00a0&\u00a0Sons.'),
          ('1933', 'Repeal. Seagram has aged stock to\u00a0sell.'),
          ('1939', 'Crown Royal, for the royal\u00a0tour.')]
for i, (yr, body) in enumerate(events):
    cx = X + i * (cw + gap)
    rrect(s, cx, 1.75, cw, 2.1, r=0.22, fill=WHITE, line=HAIR)
    if i == 3:
        rect(s, cx + 0.3, 1.95, 0.8, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.03, cw - 0.6, 0.6, yr, size=30, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 2.65, cw - 0.4, 1.1, body, size=16, color=INK, ls=1.15)
panorama(s, 'george-vi-toronto-1939.jpg', 4.05,
         'George VI inspects a guard of honour in Toronto, May 1939. Canada Science and Technology Museum.')
footer(s, 11)

# ---------------------------------------------------------------- 12 pour 3
pour_slide(12, 'Pour 3 of 4', ['Crown Royal', 'Fine Deluxe'],
           ['Seagram’s blend from 1939, now made by Diageo.',
            'Like the Canadian Club, a big blend built mostly on base\u00a0whisky.'],
           'Diageo, at Gimli, Manitoba', 'Blended Canadian whisky', '40%', two_line_name=True,
           widths=(3.0, 2.95, 0.85))

# ---------------------------------------------------------------- 13 three names
s = new_slide()
heading(s, 0.75, 'Three names for one product in Canadian law', size=36, w=CW, h=0.9)
names = ['Canadian whisky', 'Canadian rye whisky', 'Rye whisky']
g3 = 0.25
c3 = (CW - 2 * g3) / 3
for i, nm in enumerate(names):
    cx = X + i * (c3 + g3)
    rrect(s, cx, 1.85, c3, 1.9, r=0.26, fill=WHITE, line=HAIR)
    if i == 1:
        rect(s, cx + 0.35, 2.15, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.35, 2.35, c3 - 0.7, 1.2, nm, size=30, font=SANS, bold=True, color=INK, ls=0.95)
strip(s, 4.1, 1.5, ['None of them requires a minimum amount of rye.',
                    'The usual account dates the name to the 1800s, when a little rye in the mash set a '
                    'whisky\u00a0apart.'], size=20)
footer(s, 13)

# ---------------------------------------------------------------- 14 9.09%
big_figure(14, 'Other spirits or wine in Canadian whisky sold in the US', '9.09%',
           'One part in eleven: ten parts whisky to one part of something\u00a0else.',
           'The figure is not in Canada’s own definition of whisky, which allows caramel and flavouring. '
           'Labels rarely say what was\u00a0added.', quiet_y=4.85, head_size=30)

# ---------------------------------------------------------------- 15 the name for being light
s = new_slide()
heading(s, 0.75, 'Why Canadian whisky has a name for being light', size=34, w=CW, h=0.9)
pw = (CW - 0.25) / 2
cards = [(X, WHITE, HAIR, INK, 'Mostly base whisky',
          'The big blends sold in the US since Repeal, made for highballs and\u00a0mixing.'),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Mostly flavouring whisky',
          'All-rye and high-rye bottlings, a small share of exports until\u00a0recently.')]
for (cx, fill, edge, col, name, body) in cards:
    rrect(s, cx, 1.85, pw, 2.75, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.1, pw - 0.6, 0.7, name, size=28, font=SANS, bold=True, color=col)
    if fill == OAK:
        rect(s, cx + 0.42, 2.85, 0.9, 0.045, fill=MARK)
    text(s, cx + 0.4, 3.1, pw - 0.8, 1.4, body, size=20, color=col, ls=1.2)
strip(s, 5.0, 0.9, 'The flavouring whiskies were always made. Most of them went into the\u00a0blends.', size=20)
footer(s, 15)

# ---------------------------------------------------------------- 16 pour 4
pour_slide(16, 'Pour 4 of 4', ['Forty Creek', 'Copper Pot Reserve'],
           ['Made on the Niagara Peninsula at a distillery a winemaker took over in 1992.',
            'The grains are distilled and aged apart, then blended.'],
           ['Forty Creek Distillery,', 'Grimsby, Ontario (Campari)'], 'Canadian whisky', '43%',
           two_line_name=True, widths=(3.35, 2.6, 0.85))

# ---------------------------------------------------------------- 17 reading the label
s = new_slide()
heading(s, 0.75, 'Reading a Canadian whisky label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.8, CW, [
    (['Canadian whisky,', 'Canadian rye whisky,', 'rye whisky'],
     'The same legal product. Made in Canada, at least three years in small wood, at least\u00a040%.'),
    ('Rye', 'No minimum rye content unless the label gives one.'),
    ('Age statement', 'The age of the youngest whisky in the blend.'),
    (['Caramel, flavouring,', '9.09%'],
     'Caramel and flavouring are allowed. US bottles may hold up to 9.09% other spirits or wine. '
     'Usually not\u00a0declared.'),
], label_w=3.4, row_h=[1.3, 0.8, 0.8, 1.25], label_size=21, size=19)
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
