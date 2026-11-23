"""Hot Climate Whisky: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/hot-climate-whisky <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (Rye Country and The Long Way Back are the models). The
photographs are cropped from that deck's slide images (no other copy was kept); their credits
are the old captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PY, PW = 0.75, 4.63      # photo panel on the right of a content slide
NB = ' '            # non-breaking space


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, cap, px_w, px_h, w=PW, dark=False):
    """A photo crop right-aligned on R, at its own aspect ratio, with its credit under it."""
    h = w * px_h / px_w
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


def pour_slide(n, pour, name, note, maker, style, abv, two_line_name=False,
               widths=(2.6, 3.3, 0.75), val_size=18, note_size=21):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / ABV."""
    s = new_slide()
    bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=note_size, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.5, r=0.26, fill=WHITE, line=HAIR)
    cx = x + 0.3
    for (label, val), cw_ in zip([('Maker', maker), ('Style', style), ('ABV', abv)], widths):
        text(s, cx, 4.85, cw_, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw_, 0.8, val, size=val_size, color=INK, ls=1.1)
        cx += cw_ + 0.2
    footer(s, n)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.65, 2.0, 2.0 * LOGO_RATIO)
text(s, X, 2.45, 6.5, 1.75, ['Hot Climate', 'Whisky'], size=56, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.3, 0.9, 0.045, fill=MARK)
text(s, X, 4.5, 6.2, 0.45, 'Single malt from India and Taiwan  ·  Four pours', size=17, font=SANS, bold=True,
     color=CREAM)
text(s, X, 5.05, 6.0, 1.5,
     ['Three distilleries in Bangalore, Goa and', 'Yilan. Whisky ages fast in the heat, and', 'their labels give no age.'],
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 4.95
th = tw * 1254 / 1104
picture(s, A / 'zhuangwei-beach-yilan-1930s.jpg', 7.53, 0.55, tw, th, radius_in=0.26)
credit(s, 7.53, 0.55 + th + 0.08, tw,
       'A school trip on the beach at Zhuangwei, Yilan, 1930s, with Guishan Island offshore. '
       'Formosa Vintage Museum.', color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 Amrut, Bangalore
s = new_slide()
heading(s, 0.75, ['Amrut was founded in', 'Bangalore in 1948.'], size=36, w=6.7, h=1.3)
text(s, X, 2.3, 6.5, 3.0,
     ['India drinks more whisky than any other' + NB + 'country.',
      'For its first fifty years Amrut made the kind most Indians buy.'],
     size=23, color=INK, ls=1.2, space_after=18)
photo_right(s, 'pettah-bangalore-rice-1890.jpg',
            'The main street of the Pettah, Bangalore, from a book by Edward Peter Rice, 1890. Public domain.',
            1056, 1254)
footer(s, 2)

# ---------------------------------------------------------------- 3 Indian whisky and single malt
# The old slide had two column titles and no heading; it shows the script's.
s = new_slide()
heading(s, 0.8, 'What India calls whisky', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
cy = 1.8
# left: Indian whisky, a white card, and the engraving under it
lh = 2.72
rrect(s, X, cy, pw, lh, r=0.3, fill=WHITE, line=HAIR)
text(s, X + 0.4, cy + 0.2, pw - 0.8, 0.6, 'Indian whisky', size=28, font=SANS, bold=True, color=INK)
rows_l = ['Molasses from sugar cane', 'Neutral spirit, some malt added',
          [('Whisky in India, ', {}), ('not', {'bold': True}), (' in the EU', {})]]
yy = cy + 0.88
for ln in rows_l:
    line(s, X + 0.4, yy, X + pw - 0.4, yy, HAIR, 1.0)
    text(s, X + 0.4, yy + 0.04, pw - 0.8, 0.56, [ln], size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    yy += 0.58
ph = pw * 270 / 905
picture(s, A / 'sugar-cane-bullock-mill-samuelson-1890.jpg', X, cy + lh + 0.15, pw, ph, radius_in=0.18)
credit(s, X, cy + lh + 0.15 + ph + 0.06, pw,
       ['Crushing sugar cane with a bullock mill.',
        [('From James Samuelson, ', {}), ('India, Past and Present', {'italic': True}), (', 1890.', {})]])
# right: single malt, the raised green card
gx = X + pw + 0.25
gh = lh + 0.15 + ph
rrect(s, gx, cy, pw, gh, r=0.3, fill=OAK, line=OAK_EDGE)
text(s, gx + 0.4, cy + 0.2, pw - 0.8, 0.6, 'Single malt', size=28, font=SANS, bold=True, color=CREAM)
rect(s, gx + 0.42, cy + 0.8, 0.9, 0.045, fill=MARK)
rows_r = ['Malted barley only', 'One distillery, pot stills',
          [('Whisky in India ', {}), ('and', {'bold': True}), (' the EU', {})]]
yy = cy + 0.88
for ln in rows_r:
    line(s, gx + 0.4, yy, gx + pw - 0.4, yy, OAK_EDGE, 1.0)
    text(s, gx + 0.4, yy + 0.04, pw - 0.8, 0.56, [ln], size=19, color=CREAM, anchor=MSO_ANCHOR.MIDDLE)
    yy += 0.58
text(s, gx + 0.4, yy + 0.25, pw - 0.8, 1.3,
     'EU rule: whisky is distilled from malted cereals and aged at least three years in wood.',
     size=17, color=CREAM_MUTE, ls=1.2)
footer(s, 3)

# ---------------------------------------------------------------- 4 2004 (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 6.6, 1.8, '2004', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 6.7, 1.6, ['Amrut launches its single', 'malt in Glasgow.'],
     size=28, font=SANS, bold=True, color=CREAM, ls=0.98)
text(s, X, 4.0, 6.6, 2.0,
     'Indians who could pay single-malt prices bought Scotch. Amrut decided to sell to Scotland first.',
     size=19, color=CREAM_MUTE, ls=1.25)
photo_right(s, 'king-street-glasgow-annan-1870.jpg',
            'King Street, Glasgow, photographed by Thomas Annan around 1870. Public domain.',
            1056, 1284, w=4.45, dark=True)
footer(s, 4, dark=True)

# ---------------------------------------------------------------- 5 selling in Britain
s = new_slide()
heading(s, 0.85, 'Selling an Indian malt in Britain', size=40, w=CW, h=0.9)
gap = 0.3
cw = (CW - 2 * gap) / 3
cards = [('2004', 'On sale in Glasgow from 24' + NB + 'August.'),
         ('2004–09', 'Sold to shops and restaurants a few bottles at a' + NB + 'time.'),
         ('2010', [[('Jim Murray’s ', {}), ('Whisky Bible', {'italic': True}),
                    (' gives Amrut Fusion 97 points, third in the' + NB + 'world.', {})]])]
for i, (yr, body) in enumerate(cards):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.0, cw, 3.2, r=0.26, fill=WHITE, line=HAIR)
    if i == 2:
        rect(s, cx + 0.35, 2.25, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.35, 2.4, cw - 0.6, 0.8, yr, size=40, font=SANS, bold=True, color=INK)
    text(s, cx + 0.35, 3.3, cw - 0.6, 1.6, body, size=20, color=INK, ls=1.2)
strip(s, 5.45, 1.0, 'The founder’s grandson, Rakshit Jagdale, led the launch. His father Neelakanta ran the'
      + NB + 'company.', size=20)
footer(s, 5)

# ---------------------------------------------------------------- 6 pour 1
pour_slide(6, 'Pour 1 of 4', 'Amrut Fusion',
           ['Neat first, then a few drops of water.', 'Notice how early the oak comes through.'],
           ['Amrut Distilleries,', 'Bangalore'], ['Indian single malt,', 'partly peated'], '50%')

# ---------------------------------------------------------------- 7 a year in the warehouse
s = new_slide()
heading(s, 0.85, 'What a year in the warehouse costs', size=40, w=CW, h=0.9)
pw = (CW - 0.3) / 2
stats = [('2%', 'Scotland', 'Lost from a cask each year, on' + NB + 'average.'),
         ('9–12%', 'Bangalore', 'Lost each year, by Amrut’s own figures.')]
for i, (big, place, body) in enumerate(stats):
    cx = X + i * (pw + 0.3)
    rrect(s, cx, 1.95, pw, 3.2, r=0.26, fill=WHITE, line=HAIR)
    if i == 1:
        rect(s, cx + 0.4, 2.2, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.4, 2.3, pw - 0.8, 1.3, big, size=80, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.4, 3.7, pw - 0.8, 0.5, place, size=24, font=SANS, bold=True, color=INK)
    text(s, cx + 0.4, 4.25, pw - 0.8, 0.8, body, size=19, color=INK, ls=1.2)
strip(s, 5.45, 1.05, 'Amrut’s master blender puts a year in Bangalore at about three in Scotland. That is the '
      'company’s own' + NB + 'estimate.', size=19)
footer(s, 7)

# ---------------------------------------------------------------- 8 what is left in the cask
s = new_slide()
heading(s, 0.85, 'What is left in the cask', size=40, w=CW, h=0.9)
rows = [('4 years', 92, 66), ('8 years', 85, 43), ('12 years', 78, 28)]
bx = X + 1.9                     # bars start
bmax = 8.6                       # width of the longest value (92%)
rh = 1.0
y0 = 1.9
for i, (lab, sc, hot) in enumerate(rows):
    yy = y0 + i * rh
    line(s, X, yy, R, yy, HAIR, 1.0)
    text(s, X, yy, 1.8, rh, lab, size=24, font=SANS, bold=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    for j, (v, fill) in enumerate([(sc, W200), (hot, INK)]):
        by = yy + 0.17 + j * 0.38
        w_ = bmax * v / 92
        rect(s, bx, by, w_, 0.32, fill=fill)
        text(s, bx + w_ + 0.12, by - 0.04, 1.0, 0.4, '%d%%' % v, size=18, font=SANS, bold=True, color=INK,
             anchor=MSO_ANCHOR.MIDDLE)
line(s, X, y0 + 3 * rh, R, y0 + 3 * rh, HAIR, 1.0)
ly = y0 + 3 * rh + 0.3
rect(s, X, ly + 0.08, 0.32, 0.22, fill=W200)
text(s, X + 0.45, ly, 3.5, 0.4, 'Scotland, 2% a year', size=17, font=SANS, color=INK)
rect(s, X + 3.6, ly + 0.08, 0.32, 0.22, fill=INK)
text(s, X + 4.05, ly, 3.8, 0.4, 'Hot warehouse, 10% a year', size=17, font=SANS, color=INK)
dot(s, X + 3.42, ly + 0.19, 0.12, MARK_DEEP)
text(s, X, ly + 0.6, CW, 0.9,
     'This assumes the same loss every year. Amrut says it loses 9–12% a year. Paul' + NB + 'John says' + NB + '8–10%.', size=18, italic=True, color=MUTE, ls=1.2)
footer(s, 8)

# ---------------------------------------------------------------- 9 Paul John
s = new_slide()
heading(s, 0.75, ['Paul John: malt from', 'Goa, first sold in 2012'], size=36, w=6.7, h=1.3)
rows_card(s, X, 2.2, 6.7, [
    ('Firm', 'John Distilleries, the company of Paul P. John, based in Bangalore.'),
    ('Goa', 'The malt distillery, at Cuncolim near the south Goa coast.'),
    ('8–10%', 'Lost from each cask a year, by the company’s figures.'),
], label_w=1.35, row_h=1.15, mark=1, label_size=24, size=18.5)
photo_right(s, 'nova-goa-plan-1888.jpg',
            'Plan of Nova Goa (Panjim), the capital, copied by José Francisco da Silva, 1888. Public domain.',
            1056, 1254)
footer(s, 9)

# ---------------------------------------------------------------- 10 pour 2
pour_slide(10, 'Pour 2 of 4', ['Paul John', 'Brilliance'],
           ['Indian six-row barley and ex-bourbon casks, with no peat.', 'Taste it beside the Amrut.'],
           ['John Distilleries,', 'Goa'], ['Indian single malt,', 'unpeated'], '46%', two_line_name=True,
           note_size=20)

# ---------------------------------------------------------------- 11 Kavalan
s = new_slide()
heading(s, 0.75, ['Kavalan: private distilling', 'in Taiwan from 2002'], size=38, w=CW, h=1.35)
rows_card(s, X, 2.3, CW, [
    ('2002', 'Taiwan joins the WTO. The state alcohol monopoly ends.'),
    ('2005', 'King Car, a drinks group founded by Lee Tien-tsai in 1979, builds a malt distillery in Yilan'
             + NB + 'County.'),
    ('2006', 'First spirit, on 11' + NB + 'March.'),
    ('2008', 'First bottles, in December.'),
], label_w=1.5, row_h=1.05, label_size=30, size=20.5)
footer(s, 11)

# ---------------------------------------------------------------- 12 the Leith tasting
s = new_slide()
heading(s, 0.75, ['January 2010: Kavalan wins', 'a blind tasting in Leith'], size=38, w=CW, h=1.35)
rows_card(s, X, 2.3, CW, [
    ('Kavalan', 'Reported as two years old. 27.5 points out of 40.'),
    ('The rest', 'Young Scotch blends and malts, and St George’s, an English malt.'),
], label_w=2.2, row_h=0.95, mark=0, label_size=26, size=21)
text(s, X, 4.5, CW, 1.6,
     [[('Charles MacLean organised it for ', {}), ('The Times', {'italic': True}),
       (' around Burns Night, with four judges.', {})],
      [('In 2015 Kavalan Solist Vinho Barrique was named World’s Best Single Malt at the World Whiskies'
        + NB + 'Awards.', {'color': MUTE})]],
     size=21, color=INK, ls=1.2, space_after=12)
footer(s, 12)

# ---------------------------------------------------------------- 13 pour 3
pour_slide(13, 'Pour 3 of 4', 'Kavalan Classic',
           ['The distillery’s first single malt, released in 2008.',
            'Look at the colour from a distillery that began in 2006.'],
           ['Kavalan (King Car),', 'Yilan, Taiwan'], 'Taiwanese single malt', '43% (US)',
           widths=(2.6, 2.95, 1.1))

# ---------------------------------------------------------------- 14 why no age
s = new_slide()
heading(s, 0.85, 'Why these labels carry no age', size=40, w=CW, h=0.9)
rows_card(s, X, 1.95, CW, [
    ('Cost', 'At twelve years a hot warehouse needs nearly three casks for each one in Scotland.'),
    ('Comparison', 'Four years is very young in Scotland. In Yilan the oak has done far' + NB + 'more.'),
    ('The makers’ case', 'Time is a poor measure when the climate differs this much. It also suits a '
                         'distillery with no old' + NB + 'stock.'),
], label_w=3.0, row_h=1.05, label_size=23, size=20)
strip(s, 5.45, 0.85, 'Where an age is stated, it is the youngest whisky in the bottle.', size=20)
footer(s, 14)

# ---------------------------------------------------------------- 15 pour 4
pour_slide(15, 'Pour 4 of 4', ['Glenfiddich', '12 Year Old'],
           ['Twelve years in Speyside, losing about 2% a year.', 'Compare it with the Kavalan.'],
           ['William Grant & Sons,', 'Dufftown'], ['Speyside single', 'malt Scotch'], '40%', two_line_name=True)

# ---------------------------------------------------------------- 16 reading the label
s = new_slide()
heading(s, 0.85, 'Reading a world whisky label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('Single malt', 'Malted barley, one distillery. Defined in Scotch and EU' + NB + 'law.'),
    ('Whisky, in the EU', 'From malted cereals, at least three years in wood. Molasses spirit does not'
                          + NB + 'qualify.'),
    ('Age statement', 'The youngest whisky in the bottle.'),
    ('No age statement', 'Normal for hot-country malts. Says little either way.'),
], label_w=3.4, row_h=1.05, label_size=22, size=20)
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
