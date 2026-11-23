"""Cardhu: The Women Behind Johnnie Walker's Malt, slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/cardhu <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there. Layout follows tools/decks/sources/peat-reek.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PX, PW = 7.85, 4.63      # photo panel on the right of a content slide
LW = 6.55                # text column beside a photo


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, ph, cap, y=0.75, dark=False):
    picture(s, A / name, PX, y, PW, ph, radius_in=0.26)
    credit(s, PX, y + ph + 0.08, PW, cap, color=CREAM_MUTE if dark else MUTE)


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


def pour_slide(n, pour, name, note, maker, style, abv, two_line_name=False):
    """One pour: a bottle-shaped placeholder card (no free photograph of the bottles),
    the pour line, the name, a short note, and Maker / Style / ABV."""
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
text(s, X, 2.75, 6.3, 0.95, 'Cardhu:', size=60, font=SANS, bold=True, color=CREAM, ls=0.9)
text(s, X, 3.7, 6.3, 1.2, ['The Women Behind', 'Johnnie Walker’s Malt'], size=34, font=SANS, bold=True,
     color=CREAM, ls=0.98)
rect(s, X + 0.03, 5.05, 0.9, 0.045, fill=MARK)
text(s, X, 5.25, 6.0, 1.3,
     'Helen and Elizabeth Cumming, and the distillery their family sold to '
     'John Walker & Sons in 1893.', size=18, italic=True, color=CREAM_MUTE, ls=1.2)
tw, th = 5.13, 5.83
picture(s, A / 'cardhu-2007.jpg', 7.35, 0.6, tw, th, radius_in=0.26)
credit(s, 7.35, 0.6 + th + 0.08, tw,
       'Cardhu distillery, 2007. Photo: Cls With Attitude, Wikimedia Commons, CC BY-SA 2.5, cropped.',
       color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 pour 1
pour_slide(2, 'Glass 1 of 4', 'Cardhu 12 Year Old',
           ['The distillery’s own single malt.'],
           'Cardhu, Knockando', 'Speyside single malt, 12 years', '40%')

# ---------------------------------------------------------------- 3 the farm
s = new_slide()
heading(s, 0.75, ['John and Helen Cumming', 'leased Cardow in 1811'], size=36, w=CW, h=1.3)
rows_card(s, X, 2.3, CW, [
    ('The farm', 'Cardow, a hill farm above the Spey in the parish of Knockando'),
    ('The lease', 'Nineteen years, from Whitsunday 1811, in John’s name'),
    ('The whisky', 'Made on the farm without a licence. One account says Helen made it.'),
], label_w=2.2, row_h=0.95, mark=2, label_size=22, size=19)
rrect(s, X, 5.5, CW, 0.9, r=0.2, fill=W100)
text(s, X + 0.3, 5.5, CW - 0.6, 0.9,
     [[('“A wild and desolate district.”  ', {'italic': True}),
       ('Alfred Barnard, on the road to Cardow, 1887', {'font': SANS, 'size': 15, 'color': MUTE})]],
     size=21, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 3)

# ---------------------------------------------------------------- 4 the stories
s = new_slide()
heading(s, 0.75, ['The stories told', 'about Helen Cumming'], size=36, w=LW, h=1.3)
rows_card(s, X, 2.3, LW, [
    ('Flour', ['She hid the still and said', 'she had been baking.']),
    ('Flag', ['While the excisemen ate, she', 'raised a red flag for the neighbours.']),
    ('Elgin', ['She walked barefoot over the', 'hills to deliver whisky.']),
], label_w=1.25, row_h=1.0, mark=1, size=17)
text(s, X, 5.6, LW, 0.8, ['Stories passed down by the family', 'and the distillery.'],
     size=18, italic=True, color=MUTE, ls=1.15)
lh = PW * 761 / 944
photo_right(s, 'landseer-illicit-still-1829.jpg', lh,
            'Edwin Landseer, The Illicit Highland Whisky Still, 1829. Apsley House, London. Public domain, '
            'cropped. Not a picture of Cardow.')
footer(s, 4)

# ---------------------------------------------------------------- 5 the licence
s = new_slide()
heading(s, 0.85, 'Cardow was licensed in 1824', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('1823', 'An Excise Act cuts the duty, to bring illicit distillers into the legal trade.'),
    ('1824', 'John Cumming takes out a licence for Cardow.'),
    ('1824–72', 'Their son Lewis, 21 when the licence is granted, runs the distillery.'),
    ('1872', 'Lewis dies in February, aged 69.'),
], label_w=1.9, row_h=1.02, mark=1, label_size=28, size=19)
footer(s, 5)

# ---------------------------------------------------------------- 6 Elizabeth (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 7.0, 1.8, '1872', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 11.0, 0.8, 'Elizabeth Cumming takes over Cardow.', size=32, font=SANS,
     bold=True, color=CREAM, ls=0.95)
text(s, X, 3.75, 10.5, 2.6, [
    'Lewis Cumming’s widow, 24 years younger than him and a local farmer’s daughter.',
    'She was pregnant with her fourth child. Their five-year-old daughter died three days after her father.',
    [('Barnard later names her only as “Mrs. Cumming, the proprietress”.', {'color': CREAM_MUTE})],
], size=20, color=CREAM, ls=1.2, space_after=12)
footer(s, 6, dark=True)

# ---------------------------------------------------------------- 7 the new distillery
s = new_slide()
heading(s, 0.75, ['Elizabeth built a new', 'distillery in 1884'], size=36, w=LW, h=1.3)
rows_card(s, X, 2.3, LW, [
    ('Old works', ['Straggling and primitive,', 'on land held on a lease']),
    ('New works', ['Built 1884–85 on ground', 'of her own, beside the old']),
    ('Gallons', ['25,000 a year at the old works;', 'the new could make 60,000']),
], label_w=1.75, row_h=0.95, mark=1, size=17)
text(s, X, 5.45, LW, 1.2,
     [[('“A single gallon of it is sufficient to cover ten gallons of plain Spirit.”', {'italic': True})],
      [('Alfred Barnard, 1887', {'font': SANS, 'size': 13, 'color': MUTE})]],
     size=18, color=INK, ls=1.15, space_after=4)
wh = PW * 1188 / 1389
photo_right(s, 'cardhu-warehouses-2018.jpg', wh,
            'Stone warehouses at Cardhu, 2018. Photo: Anne Burgess, Geograph, CC BY-SA 2.0, cropped.')
footer(s, 7)

# ---------------------------------------------------------------- 8 the old stills
s = new_slide()
heading(s, 0.75, ['The old stills went', 'to Glenfiddich'], size=36, w=LW, h=1.3)
rows_card(s, X, 2.3, LW, [
    ('Jan 1886', ['Elizabeth refuses an offer for', 'Cardow: “it would not be justice', 'to my family”']),
    ('1886', ['William Grant buys the old plant,', 'stills included, for about £120']),
    ('Dec 1887', ['Glenfiddich’s first spirit runs', 'on Christmas Day']),
], label_w=1.5, row_h=1.15, mark=1, label_size=19, size=16.5)
sh = PW * 939 / 1389
photo_right(s, 'glenfiddich-stills-2003.jpg', sh,
            'Stills at Glenfiddich, 2003: today’s stills, not the Cardow pair. Photo: Colin Smith, Geograph, '
            'CC BY-SA 2.0, cropped.')
footer(s, 8)

# ---------------------------------------------------------------- 9 pour 2
pour_slide(9, 'Glass 2 of 4', 'Glenfiddich 12 Year Old',
           ['Started by William Grant with Cardow’s old stills.',
            'Glass 1 and this one are both 12 years old.'],
           'Glenfiddich, Dufftown', 'Speyside single malt, 12 years', '40%')

# ---------------------------------------------------------------- 10 the sale
s = new_slide()
heading(s, 0.75, ['In 1893 the Cummings sold Cardow', 'to John Walker & Sons'], size=36, w=CW, h=1.3)
stats = [('£20,500', 'the price', 'Signed on 19 September 1893, not counting the whisky in stock.'),
         ('100', 'Walker shares', 'Worth £5,000, for Elizabeth’s son John, who went on running Cardow.'),
         ('1', 'seat on the board', 'Also for John, who stayed a Walker director until 1923.')]
g3 = 0.25
c3 = (CW - 2 * g3) / 3
for i, (big, label, body) in enumerate(stats):
    cx = X + i * (c3 + g3)
    rrect(s, cx, 2.25, c3, 3.0, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.35, 2.45, c3 - 0.7, 0.95, big, size=50, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.35, 3.4, c3 - 0.7, 0.45, label, size=20, font=SANS, bold=True, color=MUTE)
    text(s, cx + 0.35, 3.95, c3 - 0.6, 1.2, body, size=16.5, color=INK, ls=1.2)
rrect(s, X, 5.5, CW, 0.85, r=0.2, fill=W100)
text(s, X + 0.3, 5.5, CW - 0.6, 0.85,
     'Cardow was Walker’s first distillery. Elizabeth died the next May, aged 67.',
     size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 10)

# ---------------------------------------------------------------- 11 Cardhu in Johnnie Walker
s = new_slide()
heading(s, 0.85, 'Diageo calls Cardhu a key malt in Johnnie Walker', size=36, w=CW, h=0.9)
text(s, X, 1.8, CW, 0.9,
     [[('“A key single malt in Johnnie Walker today.”  ', {'italic': True}),
       ('Diageo, 2019', {'font': SANS, 'size': 15, 'color': MUTE})]],
     size=24, color=INK)
corners = [('Cardhu', 'Speyside'), ('Glenkinchie', 'Lowlands'), ('Caol Ila', 'Islay'), ('Clynelish', 'Highlands')]
gap = 0.22
cw4 = (CW - 3 * gap) / 4
for i, (name, region) in enumerate(corners):
    cx = X + i * (cw4 + gap)
    rrect(s, cx, 2.85, cw4, 1.9, r=0.26, fill=WHITE, line=HAIR)
    if i == 0:
        rect(s, cx + 0.3, 3.1, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 3.3, cw4 - 0.6, 0.6, name, size=26, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.95, cw4 - 0.55, 0.5, region, size=18, color=MUTE)
text(s, X, 4.95, CW, 0.4, 'The four distilleries Diageo presents as homes of Johnnie Walker.',
     size=17, italic=True, color=MUTE)
rrect(s, X, 5.55, CW, 0.8, r=0.2, fill=W100)
text(s, X + 0.3, 5.55, CW - 0.6, 0.8,
     'Diageo does not publish its blend recipes. Whisky guides list Cardhu in Black Label.',
     size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 11)

# ---------------------------------------------------------------- 12 pour 3
pour_slide(12, 'Glass 3 of 4', ['Johnnie Walker', 'Black Label'],
           ['The firm that bought Cardow in 1893.'],
           'John Walker & Sons', 'Blended Scotch, 12 years', '40%', two_line_name=True)

# ---------------------------------------------------------------- 13 2003
s = new_slide()
heading(s, 0.85, 'In 2003 Diageo sold Cardhu Pure Malt', size=40, w=CW, h=0.9)
rows_card(s, X, 1.95, CW, [
    ('1990s', 'Sales in Spain and Portugal rise from 30,000 to 280,000 cases a year.'),
    ('July 2003', 'Cardhu Pure Malt: several Speyside malts in a near-identical bottle.'),
    ('Dec 2003', 'After rival distillers protest, Diageo agrees to a green bottle.'),
    ('March 2004', 'Diageo drops the pure malt and says the single malt will return.'),
], label_w=2.2, row_h=1.05, mark=1, label_size=22, size=18.5)
footer(s, 13)

# ---------------------------------------------------------------- 14 2009
s = new_slide()
heading(s, 0.85, 'Since 2009 the law bans “pure malt”', size=40, w=CW, h=0.9)
text(s, X, 1.75, CW, 0.5, 'The Scotch Whisky Regulations 2009, in force from 23 November 2009.',
     size=20, italic=True, color=MUTE)
rules = [('Blended malt', 'The name for single malts from more than one distillery.'),
         ('“Pure malt”', 'Not allowed on any Scotch label or advertisement.'),
         ('Cardhu', 'A listed distillery name: as a brand, only for whisky wholly distilled there.')]
for i, (t, body) in enumerate(rules):
    cx = X + i * (c3 + g3)
    rrect(s, cx, 2.65, c3, 3.3, r=0.26, fill=WHITE, line=HAIR)
    if i == 2:
        rect(s, cx + 0.35, 2.9, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.35, 3.1, c3 - 0.7, 0.6, t, size=28, font=SANS, bold=True, color=INK)
    text(s, cx + 0.35, 3.9, c3 - 0.6, 1.9, body, size=19, color=INK, ls=1.2)
footer(s, 14)

# ---------------------------------------------------------------- 15 pour 4
pour_slide(15, 'Glass 4 of 4', ['Johnnie Walker', 'Green Label'],
           ['A blended malt, the kind of whisky Cardhu Pure Malt was.', 'Sold as Johnnie Walker Pure Malt until 2004.'],
           'John Walker & Sons', 'Blended malt, 15 years', '43%', two_line_name=True)

# ---------------------------------------------------------------- 16 Sláinte
slainte_slide('To Helen and Elizabeth Cumming.')
