"""Whiskey Cocktails: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/whiskey-cocktails <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (after the Peat Reek remake). The photographs are
cropped from that deck's slide images (no other copy was kept); their credits are the old
captions, word for word. Wording changes the review asks for are proposals in
PROPOSED-CHANGES.md, not made here.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PY, PH = 0.75, 5.5       # photo panel on the right of a content slide: top and height


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, px_w, px_h, cap, dark=False):
    """The photo at its own ratio, PH tall, right edge on R; the old caption under it."""
    pw = PH * px_w / px_h
    px = R - pw
    picture(s, A / name, px, PY, pw, PH, radius_in=0.26)
    credit(s, px, PY + PH + 0.08, pw, cap, color=CREAM_MUTE if dark else MUTE)


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


def pour_slide(n, pour, name, note, spirit, method, glass, name_size=46, photo=None, credit=None):
    """One drink: a photograph of the drink (or the placeholder card when there is none),
    the pour line, the drink, the old slide's note, and
    the old slide's Spirit / Method / Glass."""
    s = new_slide()
    bottle_panel(s, photo, X, 0.8, 3.4, 5.3, credit)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    text(s, x, 1.25, w, 0.85, name, size=name_size, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 2.4, w, 1.6, note, size=20, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.35, r=0.26, fill=WHITE, line=HAIR)
    cols = [('Spirit', spirit, 2.45), ('Method', method, 1.95), ('Glass', glass, 2.2)]
    cx = x + 0.3
    for label, val, cw in cols:
        text(s, cx, 4.85, cw, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw, 0.6, val, size=17, color=INK, ls=1.1)
        cx += cw + 0.15
    footer(s, n)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.6, 2.0, 2.0 * LOGO_RATIO)
text(s, X, 2.35, 6.2, 1.5, ['Whiskey', 'Cocktails'], size=54, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 3.98, 0.9, 0.045, fill=MARK)
text(s, X, 4.18, 6.2, 0.75, ['The Old Fashioned, the Manhattan and the Sazerac', 'Four pours'],
     size=17, font=SANS, bold=True, color=CREAM, ls=1.1)
text(s, X, 5.05, 5.9, 1.5,
     'Four drinks, made in the order they first appeared in print.', size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 5.0
th = tw * 1285 / 1104
picture(s, A / 'jerry-thomas-blue-blazer.jpg', R - tw, 0.55, tw, th, radius_in=0.26)
credit(s, R - tw, 0.55 + th + 0.08, tw, 'Jerry Thomas making a Blue Blazer, engraving. Public domain.',
       color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 the 1806 definition
s = new_slide()
heading(s, 0.85, 'The first printed definition, 1806', size=40, w=CW, h=0.9)
text(s, X, 1.95, CW, 1.2,
     '“Cock-tail is a stimulating liquor, composed of spirits of any kind, sugar, water and bitters.”',
     size=28, italic=True, color=INK, ls=1.15)
text(s, X, 3.2, CW, 0.45, 'The Balance and Columbian Repository, Hudson, New York, 13 May 1806.',
     size=18, color=MUTE)
parts = [('Spirit', 'any kind'), ('Sugar', 'to soften it'), ('Water', 'to dilute it'), ('Bitters', 'sold as medicine')]
pg = 0.5
pcw = (CW - 3 * pg) / 4
for i, (t, body) in enumerate(parts):
    cx = X + i * (pcw + pg)
    rrect(s, cx, 4.0, pcw, 2.2, r=0.26, fill=WHITE, line=HAIR)
    if i == 3:
        rect(s, cx + 0.3, 4.25, 0.9, 0.045, fill=MARK_DEEP)
    if i:
        text(s, cx - pg, 4.0, pg, 2.2, '+', size=30, font=SANS, bold=True, color=INK,
             align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    text(s, cx + 0.3, 4.5, pcw - 0.6, 0.7, t, size=32, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 5.3, pcw - 0.55, 0.6, body, size=19, color=INK)
footer(s, 2)

# ---------------------------------------------------------------- 3 whiskey in 1806
s = new_slide()
heading(s, 0.85, 'American whiskey in 1806 was young.', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('Rye', 'From farms and small distilleries in Pennsylvania, Maryland and New York.'),
    ('Corn', 'Further west, in Kentucky.'),
    ('Age', 'Mostly sold young. Long aging in charred barrels became usual later.'),
    ('Bitters', 'Bark and roots in alcohol, sold for the stomach.'),
], label_w=1.6, row_h=1.05, label_size=26, size=19)
footer(s, 3)

# ---------------------------------------------------------------- 4 pour 1
pour_slide(4, 'Pour 1 of 4', 'Plain whiskey cocktail',
           ['Rye, sugar, water and bitters, as the 1806 definition reads.'],
           'Old Overholt Rye', 'Built in the glass', 'Small tumbler', name_size=42,
           photo='plain-whiskey-cocktail.jpg',
           credit='Pictured: whiskey in a cut-glass tumbler, with no ice or garnish. Photograph: Qwertzu111111, CC BY-SA 4.0, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 5 Jerry Thomas, 1862
s = new_slide()
heading(s, 0.85, '1862: Jerry Thomas prints the recipe.', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, 6.9, [
    ('Gum syrup', '3 or 4 dashes'),
    ('Bitters', '2 dashes'),
    ('Whiskey', '1 wine glass'),
    ('Lemon', 'a piece of peel'),
    ('Ice', 'shaken and strained'),
], label_w=2.1, row_h=0.74, mark=4, label_size=21, size=19)
text(s, X, 5.95, 6.9, 0.45, 'Whiskey Cocktail, from How to Mix Drinks, New York, 1862.', size=16,
     italic=True, color=MUTE)
cx, cw5 = 8.05, R - 8.05
rrect(s, cx, 2.0, cw5, 3.8, r=0.26, fill=WHITE, line=HAIR)
rect(s, cx + 0.35, 2.3, 0.9, 0.045, fill=MARK_DEEP)
text(s, cx + 0.35, 2.5, cw5 - 0.7, 0.6, 'Since 1806', size=26, font=SANS, bold=True, color=INK)
text(s, cx + 0.35, 3.25, cw5 - 0.65, 2.4,
     'Syrup in place of loose sugar, a piece of lemon peel, and fine ice, which the 1806 definition '
     'does not mention.', size=21, color=INK, ls=1.2)
footer(s, 5)

# ---------------------------------------------------------------- 6 improved and old-fashioned
# The old slide had only the two column titles; the heading is the script's.
s = new_slide()
heading(s, 0.85, 'Improved cocktails, and the old-fashioned way', size=34, w=CW, h=0.8)
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, 'Improved, 1876',
          ['Whiskey, sugar, bitters', '+ maraschino', '+ absinthe'], None),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Old-fashioned, 1880',
          ['Sugar and a little water', 'Bitters', 'Whiskey', 'Lemon peel and ice'],
          'Printed under that name by George Kappeler, New York, 1895.')]
for (cx, fill, edge, col, name, lines_, note) in sides:
    rrect(s, cx, 1.95, pw, 4.55, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.2, pw - 0.8, 0.75, name, size=32, font=SANS, bold=True, color=col)
    yy = 3.0
    for ln in lines_:
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.4, yy + 0.04, pw - 0.8, 0.56, [ln], size=21, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 0.64
    if note:
        text(s, cx + 0.4, yy + 0.15, pw - 0.8, 0.5, note, size=16, color=CREAM_MUTE)
rect(s, X + pw + 0.25 + 0.42, 2.88, 0.9, 0.045, fill=MARK)
footer(s, 6)

# ---------------------------------------------------------------- 7 the Pendennis Club
s = new_slide()
heading(s, 0.85, 'The Pendennis Club claim is weak.', size=40, w=CW, h=0.9)
rows_card(s, X, 2.1, CW, [
    ('The story', 'A bartender at the Louisville club, founded 1881, made it for the distiller James E. Pepper, '
                  'who introduced it at the Waldorf in New York.'),
    ('The record', 'The story is first told in a 1931 book. A Chicago paper mentions old-fashioned cocktails '
                   'in 1880, before the club was founded.'),
], label_w=2.4, row_h=1.75, mark=0, label_size=28, size=21)
footer(s, 7)

# ---------------------------------------------------------------- 8 pour 2
pour_slide(8, 'Pour 2 of 4', 'Old Fashioned',
           ['Sugar, bitters, bourbon and a twist of orange peel,', 'stirred over ice. No muddled fruit.'],
           'Old Forester 86 Proof', 'Stirred over ice', 'Rocks glass',
           photo='old-fashioned.jpg',
           credit='Photograph: Erich Wagner (eventografie.de), CC BY-SA 4.0, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 9 1884 (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 7.0, 1.8, '1884', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.8, CW, 1.4, ['The Manhattan is printed', 'in a bartenders’ guide.'], size=38, font=SANS, bold=True,
     color=CREAM, ls=0.95)
text(s, X, 4.55, 10.5, 1.0,
     'O. H. Byron’s Modern Bartenders’ Guide gives two versions of whiskey, vermouth and bitters.',
     size=22, color=CREAM, ls=1.2)
text(s, X, 5.7, 10.5, 0.5, 'The name is in a syndicated New York column by 1882.', size=19, color=CREAM_MUTE)
footer(s, 9, dark=True)

# ---------------------------------------------------------------- 10 the Jennie Jerome story
s = new_slide()
heading(s, 0.75, ['The Jennie Jerome', 'story is wrong.'], size=36, w=6.6, h=1.3)
rows_card(s, X, 2.3, 7.0, [
    ('3 Nov 1874', ['Samuel Tilden is elected', 'governor of New York.']),
    ('Late 1874', 'Jennie Jerome gives a party for him at the Manhattan Club, the story says.'),
    ('30 Nov 1874', 'She gives birth to Winston Churchill at Blenheim, in England.'),
], label_w=1.75, row_h=1.2, label_size=19, size=17)
photo_right(s, 'jerome-churchill-1874.jpg', 960, 1255,
            'Jennie Jerome and Lord Randolph Churchill, Paris, 1874. Georges Penabert. Public domain.')
footer(s, 10)

# ---------------------------------------------------------------- 11 pour 3
pour_slide(11, 'Pour 3 of 4', 'Manhattan',
           ['Two parts rye to one of sweet vermouth,', 'with bitters, stirred until very cold.'],
           'Wild Turkey 101 Rye', 'Stirred, strained', 'Chilled coupe',
           photo='manhattan.jpg',
           credit='Pictured: in a cocktail glass. Photograph: Graeme Maclean, CC BY 2.0, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 12 Peychaud and the Sazerac House
s = new_slide()
heading(s, 0.75, ['Peychaud’s bitters and', 'the Sazerac House'], size=36, w=6.6, h=1.3)
rows_card(s, X, 2.3, 7.0, [
    ('1850s', ['A coffee house by Exchange Alley is', 'renamed after Sazerac cognac, which', 'its former owner imports.']),
    ('1870s', 'Thomas Handy runs the bar and buys the rights to Peychaud’s bitters.'),
    ('1899', 'The Sazerac cocktail is first named in print.'),
], label_w=1.15, row_h=1.25, mark=1, label_size=22, size=17)
photo_right(s, 'exchange-alley-new-orleans.jpg', 960, 1255,
            'Exchange Alley, New Orleans, 1900–1906. Detroit Publishing Co., public domain.')
footer(s, 12)

# ---------------------------------------------------------------- 13 cognac or rye
s = new_slide()
heading(s, 0.75, ['Cognac or rye: the printed', 'record starts with whiskey.'], size=32, w=6.9, h=1.3)
rows_card(s, X, 2.3, 6.85, [
    ('The story', 'A cognac drink until phylloxera ruined French vineyards, then rye. Told in a 1937 book.'),
    ('The record', ['The first printed recipe,', 'in 1908, uses whiskey.']),
], label_w=1.75, row_h=1.55, mark=1, label_size=21, size=18)
photo_right(s, 'phylloxera-punch-1890.jpg', 1008, 1255,
            'The phylloxera as a gourmet. Linley Sambourne, Punch, 6 September 1890. Public domain.')
footer(s, 13)

# ---------------------------------------------------------------- 14 pour 4
pour_slide(14, 'Pour 4 of 4', 'Sazerac',
           ['Served with no ice, in a glass rinsed with absinthe. The lemon peel is discarded.'],
           'Sazerac Rye', 'Stirred, strained', 'Rinsed rocks glass',
           photo='sazerac.jpg',
           credit='Pictured: with the lemon peel left on the rim. Photograph: Gtandersson, CC BY 4.0, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 15 the fruit
s = new_slide()
heading(s, 0.75, ['Where the muddled', 'fruit came from'], size=36, w=6.6, h=1.3)
rrect(s, X, 2.3, 6.4, 3.0, r=0.26, fill=WHITE, line=HAIR)
text(s, X + 0.35, 2.6, 5.7, 1.4,
     'Orange and a cherry appear in Old Fashioned recipes in 1933, the year of Repeal, as a garnish.',
     size=22, color=INK, ls=1.2)
line(s, X + 0.35, 4.05, X + 6.05, 4.05, HAIR, 1.0)
text(s, X + 0.35, 4.2, 5.7, 1.0,
     'Crushing the fruit into the drink may have started later, after the Second World War.',
     size=18, italic=True, color=MUTE, ls=1.2)
photo_right(s, 'prohibition-raid-1921.jpg', 1104, 1285,
            'Agents pour liquor into a New York sewer after a raid, 1921. Library of Congress.')
footer(s, 15)

# ---------------------------------------------------------------- 16 the stories came later
s = new_slide()
heading(s, 0.85, 'The origin stories were written down later.', size=38, w=CW, h=0.9)
events = [('1923', 'A Hoffman House bartender names a man called Black.'),
          ('1931', 'A Waldorf memoir credits the Pendennis Club.'),
          ('1933', 'Repeal. Bars reopen.'),
          ('1937', 'A New Orleans drinks book gives the cognac Sazerac.'),
          ('2007', 'David Wondrich’s book Imbibe! reprints the old recipes.')]
g5 = 0.2
c5 = (CW - 4 * g5) / 5
for i, (yr, body) in enumerate(events):
    cx = X + i * (c5 + g5)
    rrect(s, cx, 2.05, c5, 3.3, r=0.26, fill=WHITE, line=HAIR)
    if i == 4:
        rect(s, cx + 0.3, 2.3, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.45, c5 - 0.5, 0.75, yr, size=38, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.3, c5 - 0.45, 1.7, body, size=17, color=INK, ls=1.2)
rrect(s, X, 5.62, CW, 0.85, r=0.2, fill=W100)
text(s, X + 0.3, 5.62, CW - 0.6, 0.85, 'The recipes in 1862, 1884, 1895 and 1908 are older than any of the stories.',
     size=20, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 16)

# ---------------------------------------------------------------- 17 the four recipes
s = new_slide()
heading(s, 0.85, 'The four recipes, for home', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('Whiskey cocktail', '2 oz whiskey, 1 tsp sugar, a splash of water, 2 dashes Angostura.'),
    ('Old Fashioned', 'The same, stirred over ice, with orange peel.'),
    ('Manhattan', '2 oz rye, 1 oz sweet vermouth, 2 dashes Angostura. Stirred, strained.'),
    ('Sazerac', ['2 oz rye, sugar, 3 dashes Peychaud’s.', 'Absinthe-rinsed glass, lemon peel discarded.']),
], label_w=2.6, row_h=1.05, label_size=22, size=18.5)
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
