"""Bourbon Barrels Around the World: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/bourbon-barrels-around-the-world <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (the Peat Reek and Sherry Butt remakes are the models).
The photographs are cropped from that deck's slide images (no other copy was kept); their credits
are the old captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PY = 0.75                # top of a right-hand photo
PH = 5.5                 # height of a right-hand photo; its width comes from the crop's ratio


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, px_w, px_h, cap, dark=False):
    """A portrait crop at a fixed height, right-aligned on R, its credit under it. Returns its left x."""
    w = PH * px_w / px_h
    x = R - w
    picture(s, A / name, x, PY, w, PH, radius_in=0.26)
    credit(s, x, PY + PH + 0.08, w, cap, color=CREAM_MUTE if dark else MUTE)
    return x


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


def strip(s, y, h, t, size=20, x=X, w=CW):
    """The closing sentence of a slide, in a tinted strip."""
    rrect(s, x, y, w, h, r=0.2, fill=W100)
    text(s, x + 0.3, y, w - 0.6, h, t, size=size, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)


def pour_slide(n, pour, name, note, maker, style, strength, strength_label='ABV', two_line_name=False,
               note_size=21, widths=(2.55, 3.15, 1.15), photo=None, credit=None):
    """One pour: the bottle's photograph (or the placeholder card when there is none), the pour
    line, the name, the old slide's note, and Maker / Style / ABV (or Proof, as the old slide had it)."""
    s = new_slide()
    bottle_panel(s, photo, X, 0.8, 3.4, 5.3, credit)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.5, note, size=note_size, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.5, r=0.26, fill=WHITE, line=HAIR)
    cx = x + 0.3
    for label, val, cw_ in zip(('Maker', 'Style', strength_label), (maker, style, strength), widths):
        text(s, cx, 4.85, cw_, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw_, 0.8, val, size=18, color=INK, ls=1.1)
        cx += cw_ + 0.2
    footer(s, n)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 2.6, 6.4, 1.4, ['Bourbon Barrels', 'Around the World'], size=48, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.12, 0.9, 0.045, fill=MARK)
text(s, X, 4.35, 6.2, 0.45, 'Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 4.95, 5.9, 1.5,
     ['Why most Scotch whisky is aged', 'in barrels that held bourbon first.'],
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 5.13
th = tw * 1254 / 1104
picture(s, A / 'rickhouse-kentucky-nara.jpg', 7.35, 0.5, tw, th, radius_in=0.26)
credit(s, 7.35, 0.5 + th + 0.08, tw,
       ['Bourbon barrels in a Kentucky warehouse.',
        'U.S. Department of Transportation, via the National Archives. Public domain.'], color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 white oak
s = new_slide()
px = photo_right(s, 'white-oak-redoute-michaux.jpg', 960, 1254,
                 'White oak, drawn by P. J. Redouté for F. A. Michaux’s North American Sylva. Public domain.')
lw = px - 0.4 - X
heading(s, 0.75, ['The barrel starts as', 'an American white oak'], size=36, w=lw, h=1.3)
rows_card(s, X, 2.35, lw, [
    ('Grain', 'tight, with pores sealed by tyloses, so it holds liquid'),
    ('Red oak', 'has open pores and leaks'),
    ('Heat', 'lets a stave bend without breaking'),
    ('Staves', 'sawn, then seasoned outdoors'),
], label_w=1.6, row_h=0.95, mark=3, label_size=22, size=18.5)
footer(s, 2)

# ---------------------------------------------------------------- 3 the cooper
s = new_slide()
px = photo_right(s, 'millet-cooper-tightening-staves.jpg', 960, 1254,
                 ['Cooper Tightening Staves on a Barrel, Jean-François Millet,',
                  'about 1850. Museum of Fine Arts, Boston. Public domain.'])
lw = px - 0.4 - X
heading(s, 0.75, ['A cooper builds it', 'with no glue or nails'], size=36, w=lw, h=1.3)
rows_card(s, X, 2.3, lw, [
    ('Raise', 'about thirty staves stood inside a hoop'),
    ('Bend', 'heat, then draw the open end together'),
    ('Hoop', 'drive iron hoops down to hold it'),
    ('Head', 'set the ends into a groove, the croze'),
], label_w=1.35, row_h=0.82, mark=3, label_size=22, size=18.5)
strip(s, 5.85, 0.68, 'Wet wood swells and closes the joints.', size=19, w=lw)
footer(s, 3)

# ---------------------------------------------------------------- 4 inside a charred stave
# Old slide: three bands on green, the red layer filled orange. Here: char as a green card, the
# red layer as a white card with the orange mark, plain oak as a tan card, spirit on the left.
s = new_slide()
heading(s, 0.85, 'Inside a charred stave', size=40, w=CW, h=0.9)
text(s, X, 2.25, 1.3, 0.5, 'Spirit', size=22, font=SANS, bold=True, color=MUTE)
gx = X + 1.45
g = 0.2
cw = (R - gx - 2 * g) / 3
layers = [('Char', 'Works like charcoal. Takes out some sulfur notes.', OAK, OAK_EDGE, CREAM),
          ('Red layer', 'Wood sugars caramelized by heat. Vanillin, color.', WHITE, HAIR, INK),
          ('Oak', 'Tannin and oak lactones.', W100, W200, INK)]
for i, (name, body, fill, edge, col) in enumerate(layers):
    cx = gx + i * (cw + g)
    rrect(s, cx, 2.05, cw, 2.65, r=0.26, fill=fill, line=edge)
    if i == 1:
        rect(s, cx + 0.35, 2.3, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.35, 2.45, cw - 0.7, 0.6, name, size=28, font=SANS, bold=True, color=col)
    text(s, cx + 0.35, 3.2, cw - 0.6, 1.7, body, size=19, color=col, ls=1.2)
strip(s, 5.0, 0.85, 'Char is graded No. 1 to No. 4. No. 4, the heaviest, is called alligator char.')
footer(s, 4)

# ---------------------------------------------------------------- 5 1935 (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 7.0, 1.8, '1935', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, CW, 0.7, 'The Federal Alcohol Administration Act', size=32, font=SANS, bold=True, color=CREAM)
text(s, X, 3.7, 10.8, 2.8, [
    'Standards of identity written under it require bourbon to be stored in charred new oak containers. '
    'The word “new” was in them by 1938. A barrel can hold bourbon once.',
    [('The usual story is that barrel makers and the timber trade pushed for it. That has never been proved.',
      {'color': CREAM_MUTE, 'size': 19})],
], size=22, color=CREAM, ls=1.2, space_after=14)
footer(s, 5, dark=True)

# ---------------------------------------------------------------- 6 pour 1
pour_slide(6, 'Pour 1 of 4', 'Maker’s Mark',
           'Nothing may be added to bourbon but water, so all of this color came out of one new charred barrel.',
           'Maker’s Mark, Kentucky', ['Kentucky straight', 'bourbon, wheated'], '90', strength_label='Proof',
           widths=(2.95, 3.05, 0.6),
           photo='makers-mark-crop.jpg',
           credit='Photograph: U.S. National Archives, public domain, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 7 the rickhouse
s = new_slide()
heading(s, 0.85, 'Years in a Kentucky rickhouse', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('Top floors', 'hottest and driest. Water escapes faster than alcohol, so the proof tends to rise.'),
    ('Middle', 'in between'),
    ('Ground', 'coolest, slowest'),
], label_w=2.4, row_h=1.0, mark=0, label_size=24, size=19.5)
strip(s, 5.25, 1.35, ['Summer heat pushes spirit into the wood. Winter draws it back out.',
                    'Most distilleries blend barrels from different floors. Maker’s Mark moves its barrels between '
                    'floors by hand.'], size=19)
footer(s, 7)

# ---------------------------------------------------------------- 8 53 gallons (big number, on paper)
s = new_slide()
text(s, 0.75, 0.6, 7.0, 1.8, '53', size=150, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 2.65, 1.2, 0.045, fill=MARK_DEEP)
text(s, X, 2.9, CW, 1.2, ['US gallons in a standard bourbon barrel,', 'about 200 liters'],
     size=32, font=SANS, bold=True, color=INK, ls=0.98)
text(s, X, 4.4, 10.5, 1.4,
     'Some evaporates through the wood each year: about 2% in Scotland, usually more in Kentucky. '
     'It is called the angels’ share.', size=21, color=INK, ls=1.2)
footer(s, 8)

# ---------------------------------------------------------------- 9 what the first fill leaves
s = new_slide()
heading(s, 0.85, 'What the first fill leaves in the wood', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
cards = [(X, OAK, OAK_EDGE, CREAM, 'First fill, bourbon', 'New barrel. Most of the color, vanilla and tannin, '
          'taken quickly.'),
         (X + pw + 0.25, WHITE, HAIR, INK, 'Second fill, abroad', 'What is left. It comes out slowly, over ten years '
          'or more.')]
for cx, fill, edge, col, name, body in cards:
    rrect(s, cx, 2.0, pw, 2.6, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.25, pw - 0.8, 0.7, name, size=30, font=SANS, bold=True, color=col)
    if fill == OAK:
        rect(s, cx + 0.42, 2.95, 0.9, 0.045, fill=MARK)
    text(s, cx + 0.4, 3.2, pw - 0.8, 1.3, body, size=21, color=col, ls=1.2)
strip(s, 4.95, 1.05, 'Some bourbon stays soaked in the staves. Jim Beam’s Devil’s Cut is partly whiskey drawn back '
                     'out of the wood.', size=20)
footer(s, 9)

# ---------------------------------------------------------------- 10 where they go
s = new_slide()
heading(s, 0.85, 'Where the empty barrels go', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('Scotch whisky', 'Three years in oak in Scotland. New wood is not required.'),
    ('Irish whiskey', 'Three years in wooden casks on the island of Ireland.'),
    ('Rum and tequila', 'Much Caribbean rum, and much aged tequila.'),
    ('How they travel', 'Now mostly whole. Until the 1980s, as bundles of staves.'),
], label_w=3.0, row_h=0.98, label_size=23, size=20)
footer(s, 10)

# ---------------------------------------------------------------- 11 pour 2
pour_slide(11, 'Pour 2 of 4', 'Laphroaig 10',
           'Laphroaig’s ex-bourbon barrels come largely from Maker’s Mark, its sister distillery.',
           'Laphroaig, Islay', 'Islay single malt Scotch', '43% (US)', widths=(2.35, 3.2, 1.15),
           photo='laphroaig-10.jpg',
           credit='Pictured: the 40% bottling. Photograph: Datenralfi, CC BY-SA 3.0 DE, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 12 filled more than once
s = new_slide()
heading(s, 0.85, 'A Scotch cask is filled more than once', size=40, w=CW, h=0.9)
fills = [('Bourbon', 'New charred oak, used once.', 1.0),
         ('First fill', 'The most flavor left to give.', 0.6),
         ('Refill', 'Less again. Often two or three times.', 0.33),
         ('Spent', ['Scraped and', 're-charred, or retired.'], 0.14)]
g4 = 0.22
c4 = (CW - 3 * g4) / 4
base = 5.2
for i, (name, body, bar) in enumerate(fills):
    cx = X + i * (c4 + g4)
    rrect(s, cx, 1.95, c4, 1.85, r=0.24, fill=WHITE, line=HAIR)
    if i == 1:
        rect(s, cx + 0.3, 2.17, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.3, c4 - 0.6, 0.55, name, size=24, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 2.9, c4 - 0.4, 0.9, body, size=16.5, color=INK, ls=1.15)
    rect(s, cx, base - bar, c4, bar, fill=INK if i == 1 else W200)
    if i == 1:
        dot(s, cx + c4 / 2, base - bar - 0.2, 0.14, MARK_DEEP)
line(s, X, base, R, base, MUTE, 1.0)
text(s, X, base + 0.08, CW, 0.35, 'Not to scale: the wood gives less each time', size=13, italic=True, color=MUTE)
strip(s, 5.82, 0.78, 'Most single malts mix first-fill and refill casks. Labels rarely say in what proportion.',
      size=19)
footer(s, 12)

# ---------------------------------------------------------------- 13 pour 3
pour_slide(13, 'Pour 3 of 4', 'Slane Irish Whiskey',
           'Brown-Forman owns Slane and Jack Daniel’s and builds its own barrels. Part of this whiskey aged in '
           'casks that held Tennessee whiskey and bourbon.',
           'Slane, County Meath', ['Blended Irish whiskey,', 'three cask types'], '40%', note_size=20,
           widths=(2.55, 3.4, 0.85))

# ---------------------------------------------------------------- 14 Glenmorangie lends the barrel
s = new_slide()
heading(s, 0.75, 'Glenmorangie buys the tree and lends the barrel', size=36, w=CW, h=0.8)
steps = [('Missouri', 'Oak chosen in the Ozarks', WHITE, HAIR),
         ('Seasoned', 'Staves air-dried for about two years', WHITE, HAIR),
         ('Coopered', 'Built to the distillery’s order', WHITE, HAIR),
         (['Kentucky or', 'Tennessee'], 'Lent to a distiller for about four years', W100, W200),
         ('Tain', 'Shipped to Scotland for its second fill', WHITE, HAIR)]
g5 = 0.2
c5 = (CW - 4 * g5) / 5
for i, (name, body, fill, edge) in enumerate(steps):
    cx = X + i * (c5 + g5)
    rrect(s, cx, 1.62, c5, 2.18, r=0.22, fill=fill, line=edge)
    if i == 4:
        rect(s, cx + 0.25, 1.82, 0.8, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.25, 1.94, c5 - 0.4, 0.75, name, size=20, font=SANS, bold=True, color=INK, ls=0.95)
    text(s, cx + 0.25, 2.72, c5 - 0.4, 1.05, body, size=16, color=INK, ls=1.15)
text(s, X, 3.95, CW, 0.4, 'This is how Glenmorangie describes it. It calls these designer casks.', size=19, color=INK)
bh = CW * 298 / 2060
picture(s, A / 'stave-bolts-truck-nara.jpg', X, 4.55, CW, bh, radius_in=0.2)
credit(s, X, 4.55 + bh + 0.08, CW,
       'A Chevrolet truck loaded with white oak stave bolts. U.S. Forest Service photograph, National Archives. '
       'Public domain.')
footer(s, 14)

# ---------------------------------------------------------------- 15 pour 4
pour_slide(15, 'Pour 4 of 4', ['Glenmorangie', 'The Original 12'],
           'Twelve years in ex-bourbon casks, with no peat.',
           'Glenmorangie, Tain', 'Highland single malt Scotch', '40%', two_line_name=True,
           widths=(2.55, 3.4, 0.85),
           photo='glenmorangie-original.jpg',
           credit='Pictured: the 10 year old sold until 2024. Photograph: Datenralfi, CC BY-SA 3.0 DE, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 16 reading the label
s = new_slide()
heading(s, 0.85, 'Reading the wood on a label', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    (['Bourbon,', 'straight bourbon'], 'New charred oak and no added color, by law.'),
    ('Ex-bourbon, first fill, refill', 'A used cask, and how often it was used. Optional.'),
    ('Double oaked, finished', 'Moved to a second cask near the end.'),
    ('Natural colour', 'Scotch may contain caramel coloring without saying so.'),
], label_w=3.75, row_h=1.0, label_size=21, size=19.5)
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
