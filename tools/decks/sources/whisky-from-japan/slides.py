"""Whisky From Japan: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py <this folder> <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.
"""
from pptx.oxml.ns import qn

from wsskit import *

JA_FONT = 'Hiragino Sans'  # standard on a Mac; LibreOffice falls back to a Japanese system font


def ja(shape):
    """Give every run an East Asian typeface so the kana render in a Japanese font."""
    for p in shape.text_frame.paragraphs:
        for r in p.runs:
            rpr = r._r.get_or_add_rPr()
            ea = rpr.find(qn('a:ea'))
            if ea is None:
                ea = rpr.makeelement(qn('a:ea'), {})
                latin = rpr.find(qn('a:latin'))
                if latin is not None:
                    latin.addnext(ea)
                else:
                    rpr.append(ea)
            ea.set('typeface', JA_FONT)
    return shape


def label(s, y, t, color=MUTE):
    return text(s, 0.85, y, 11.6, 0.4, t, size=15, font=SANS, bold=True, color=color)


def strip(s, x, y, w, h, runs, size=15, fill=W100, color=INK):
    rrect(s, x, y, w, h, r=0.18, fill=fill)
    text(s, x + 0.3, y, w - 0.6, h, runs, size=size, color=color, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, 0.85, 0.75, 1.9, 1.9 * LOGO_RATIO)
ja(text(s, 0.85, 2.55, 6.0, 0.5, 'ウイスキー', size=20, font=SANS, color=CREAM_MUTE))
text(s, 0.85, 3.05, 6.6, 1.0, 'Whisky From Japan', size=48, font=SANS, bold=True, color=CREAM, ls=0.95)
rect(s, 0.88, 4.2, 0.9, 0.045, fill=MARK)
text(s, 0.85, 4.45, 6.0, 0.6, 'Hakata: a whisky made in Japan that cannot be labeled Japanese whisky', size=24, italic=True, color=CREAM_MUTE)
text(s, 0.85, 6.3, 6.4, 0.6, 'The Whiskey Share Society  ·  Hakata  ·  Hikari Distillery, Fukuoka',
     size=11, font=SANS, color=CREAM_MUTE)
picture(s, A / 'title_print.jpg', 7.58, 0.85, 4.9, 5.75, radius_in=0.3)

# ---------------------------------------------------------------- 2 Perry
s = new_slide()
text(s, 0.85, 0.75, 8, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), ('Glass 1', {})]],
     size=15, font=SANS, bold=True, color=INK)
label(s, 1.2, 'How whisky reached Japan')
heading(s, 1.62, 'Japan had no whisky until the late nineteenth century.', size=30, h=1.0)
picture(s, A / 'perry.jpg', 0.85, 2.55, 3.0, 3.75, radius_in=0.22)
text(s, 0.85, 6.38, 3.0, 0.3, 'Commodore Matthew Perry, 1853', size=10.5, font=SANS, color=MUTE)
text(s, 4.35, 2.55, 8.13, 3.0, [
    [('The country had been sealed for more than two hundred years.', {'bold': True, 'font': SANS, 'size': 18.5})],
    'An American naval squadron under Commodore Perry forced it open in 1853. Whisky came with the expedition and with the traders and diplomats who followed.',
    'Whisky has been drunk in Japan for about a hundred and fifty years. It has been made there for about a hundred.',
], size=17.5, ls=1.25, space_after=11)
strip(s, 4.35, 5.55, 8.13, 0.85, [[('1853  ·  ', {'bold': True, 'font': SANS}),
                                   ('Perry forces the ports open. Whisky arrives with his ships and the traders who follow.', {})]],
      size=15)
footer(s, 2)

# ---------------------------------------------------------------- 3 Torii and Taketsuru
s = new_slide()
label(s, 0.8, 'Torii and Taketsuru')
heading(s, 1.22, 'Torii and Taketsuru built Japan’s first distillery together, then split.', size=28, h=1.0)
picture(s, A / 'torii.jpg', 0.85, 2.45, 1.36, 2.0, radius_in=0.18)
picture(s, A / 'tasting.jpg', 6.88, 2.45, 3.64, 2.0, radius_in=0.18)
for x, name, body, year, when in [
    (0.85, 'Torii Shinjiro', 'A drinks merchant. He wanted a whisky suited to Japanese tastes.',
     '1923', 'Builds Yamazaki, Japan’s first whisky distillery, and hires Taketsuru on a ten-year contract to run it.'),
    (6.88, 'Masataka Taketsuru',
     'Son of a sake brewer. Studied chemistry at Glasgow, apprenticed at Hazelburn, and kept detailed notebooks.',
     '1934', 'His contract with Yamazaki ends. He leaves Kotobukiya, goes north to Hokkaido for a climate like Scotland’s, and founds his own company. It becomes Nikka.'),
]:
    text(s, x, 4.58, 5.6, 0.4, name, size=17, font=SANS, bold=True, color=INK)
    text(s, x, 4.95, 5.6, 0.85, body, size=14.5, ls=1.1)
    text(s, x, 5.88, 5.6, 0.9, [[(year + '  ·  ', {'bold': True, 'font': SANS}), (when, {})]], size=14, ls=1.1)
line(s, 6.6, 2.45, 6.6, 6.6, HAIR, 1.0)
footer(s, 3)

# ---------------------------------------------------------------- 4 Rita (story slide on green)
s = new_slide(INK)
text(s, 0.85, 0.85, 6.0, 0.4, 'Rita Cowan', size=15, font=SANS, bold=True, color=CREAM_MUTE)
heading(s, 1.3, 'Rita Taketsuru', size=48, color=CREAM, w=6.4, h=0.9)
text(s, 0.85, 2.45, 6.1, 4.0, [
    'Jessie Roberta Cowan of Kirkintilloch, a doctor’s daughter, married Taketsuru in 1920 against the wishes of both families and moved to Japan with him.',
    'While Yamazaki’s first whisky aged, she taught English and piano to support them.',
    'When his contract ended in 1934 they moved to Hokkaido, where he founded Nikka.',
], size=19, color=CREAM, ls=1.25, space_after=12)
rrect(s, 7.45, 0.85, 5.03, 5.65, r=0.4, fill=OAK, line=OAK_EDGE)
rect(s, 7.95, 1.55, 0.9, 0.045, fill=MARK)
text(s, 7.95, 1.85, 4.1, 2.4, 'Japan calls her the Mother of Japanese Whisky.', size=32, italic=True, color=CREAM, ls=1.15)
text(s, 7.95, 4.6, 4.1, 1.5, 'Her home district and Yoichi have been twin towns since 1988. The road in front of Yoichi station is called Rita Road.',
     size=14, font=SANS, color=CREAM_MUTE, ls=1.2)
footer(s, 4, dark=True)

# ---------------------------------------------------------------- 5 the standard
s = new_slide()
label(s, 0.8, 'The 2021 standard')
heading(s, 1.22, 'Until 2021 there was no definition of “Japanese whisky”.', size=27, h=0.6)
rules = [
    'Water must be extracted in Japan.',
    'Saccharification, fermentation and distillation must happen at a Japanese distillery.',
    [('Distillers must always use ', {}), ('malted', {'bold': True}), (' grains.', {})],
    'Matured in wooden casks, in Japan, for at least three years.',
    'Bottled only in Japan, at 40% abv or higher.',
]
rrect(s, 0.85, 2.0, 11.63, 3.6, r=0.26, fill=WHITE, line=HAIR)
yy = 2.18
for i, r in enumerate(rules, 1):
    if i == 3:
        rrect(s, 1.05, yy - 0.06, 11.23, 0.66, r=0.16, fill=W100)
        dot(s, 12.0, yy + 0.27, 0.12, MARK_DEEP)
    rrect(s, 1.25, yy + 0.04, 0.46, 0.46, r=0.15, fill=PAPER if i != 3 else WHITE)
    text(s, 1.25, yy + 0.04, 0.46, 0.46, str(i), size=15, font=SANS, bold=True, color=INK,
         align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
    text(s, 2.0, yy + 0.04, 9.8, 0.46, [r] if isinstance(r, list) else r, size=18, color=INK,
         anchor=MSO_ANCHOR.MIDDLE, bold=(i == 3))
    yy += 0.68
rrect(s, 0.85, 5.75, 11.63, 1.0, r=0.18, fill=W100)
text(s, 1.15, 5.85, 11.0, 0.4,
     'This is not a law. It is a voluntary standard set by a trade body. There is no inspection and no penalty, and not every producer is a member.',
     size=13.5, bold=True, color=INK)
text(s, 1.15, 6.35, 11.0, 0.3,
     'Japan Spirits & Liqueurs Makers Association  ·  in force 1 April 2021  ·  full compliance 31 March 2024',
     size=12, font=SANS, color=MUTE)
footer(s, 5)

# ---------------------------------------------------------------- 6 the boom: collage
s = new_slide()
ja(text(s, 0.85, 0.75, 11.6, 0.4, 'ウイスキー  ·  The boom', size=15, font=SANS, bold=True, color=MUTE))
heading(s, 1.15, 'In 2001 a Nikka single cask won a major international award. In 2015 a Yamazaki was named the world’s best whisky. Stocks ran short.',
        size=22, h=0.95)
x0, y0, cw, ch, g = 0.85, 2.3, 2.8325, 1.3833, 0.1


def cell(name, c, r, cs=1, rs=1, w=None):
    ww = cs * cw + (cs - 1) * g
    hh = rs * ch + (rs - 1) * g
    x = x0 + c * (cw + g)
    if w:
        x += (ww - w) / 2
        ww = w
    picture(s, A / name, x, y0 + r * (ch + g), ww, hh, radius_in=0.14)


cell('c_wave.jpg', 0, 0)
cell('c_bar.jpg', 1, 0, cs=2)
cell('c_mountain.jpg', 3, 0, rs=2)
cell('c_samurai.jpg', 0, 1, rs=2)
cell('c_highball.jpg', 1, 1)
cell('c_yamazaki.jpg', 2, 1)
cell('c_oldbar.jpg', 1, 2, cs=2)
cell('c_bottles.jpg', 3, 2, w=1.14)
footer(s, 6)

# ---------------------------------------------------------------- 7 making whisky
s = new_slide()
label(s, 0.8, 'Making whisky')
heading(s, 1.22, 'Whisky is made in six steps. Tonight is about the first.', size=30, h=0.6)
steps = ['Malting', 'Mashing', 'Fermenting', 'Distilling', 'Aging', 'Bottling']
sw = (11.63 - 5 * 0.15) / 6
for i, st in enumerate(steps):
    x = 0.85 + i * (sw + 0.15)
    if i == 0:
        rrect(s, x, 2.1, sw, 0.62, r=0.16, fill=INK)
        text(s, x, 2.1, sw, 0.62, st, size=15, font=SANS, bold=True, color=CREAM, align=PP_ALIGN.CENTER,
             anchor=MSO_ANCHOR.MIDDLE)
    else:
        rrect(s, x, 2.1, sw, 0.62, r=0.16, fill=WHITE, line=HAIR)
        text(s, x, 2.1, sw, 0.62, st, size=15, font=SANS, color=MUTE, align=PP_ALIGN.CENTER,
             anchor=MSO_ANCHOR.MIDDLE)
text(s, 0.85, 3.05, 7.0, 2.7, [
    [('Malting is how you get the enzymes.', {'bold': True, 'font': SANS, 'size': 22})],
    'Barley is soaked and allowed to start germinating. The grain releases enzymes that turn its starch into sugar. Heat stops the process.',
    [('Without enzymes there is no sugar, and without sugar nothing ferments.', {'bold': True})],
], size=17.5, ls=1.25, space_after=11)
picture(s, A / 'rings.jpg', 8.38, 3.05, 4.1, 2.75, radius_in=0.22)
strip(s, 0.85, 5.95, 7.0, 0.7, [[('Tonight’s whisky: ', {'bold': True}),
                                 ('it gets its enzymes from koji, not from malt.', {})]],
      size=15)
footer(s, 7)

# ---------------------------------------------------------------- 8 the climate map
s = new_slide()
label(s, 0.7, 'Climate')
heading(s, 1.05, 'Japan’s distilleries were sited for their climates.', size=26, h=0.5)
MX, MY, MW, MH = 4.55, 1.55, 4.2, 4.75
picture(s, A / 'japan_map.png', MX, MY, MW, MH)
K, SC, OY, LON0, LAT1 = 0.7880107536067219, 0.3135221472532254, 0.05493611032613141, 129.2, 45.7


def pt(lat, lon):
    return MX + (lon - LON0) * K * SC, MY + OY + (LAT1 - lat) * SC


def badge(x, y, n, d=0.32):
    dot(s, x, y, d, INK)
    text(s, x - d / 2, y - d / 2, d, d, str(n), size=11, font=SANS, bold=True, color=CREAM,
         align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)


cities = [('Sapporo', 43.06, 141.35, 'r'), ('Aomori', 40.82, 140.74, 'l'), ('Sendai', 38.27, 140.87, 'r'),
          ('Tokyo', 35.68, 139.69, 'r'), ('Kyoto', 35.01, 135.77, 'u'), ('Osaka', 34.69, 135.50, 'd'),
          ('Hiroshima', 34.39, 132.46, 'd')]
for name, la, lo, side in cities:
    x, y = pt(la, lo)
    dot(s, x, y, 0.07, MUTE)
    if side == 'r':
        text(s, x + 0.12, y - 0.13, 1.0, 0.26, name, size=9.5, font=SANS, color=MUTE)
    elif side == 'l':
        text(s, x - 1.1, y - 0.13, 1.0, 0.26, name, size=9.5, font=SANS, color=MUTE, align=PP_ALIGN.RIGHT)
    elif side == 'u':
        text(s, x - 0.5, y - 0.32, 1.0, 0.24, name, size=9.5, font=SANS, color=MUTE, align=PP_ALIGN.CENTER)
    else:
        text(s, x - 0.5, y + 0.06, 1.0, 0.24, name, size=9.5, font=SANS, color=MUTE, align=PP_ALIGN.CENTER)

cards = [  # n, name, owner line, caption, photo, (lat, lon), card x, card y
    (1, 'Yoichi', 'Owned by Nikka  ·  known for more peated styles', 'Cool, humid climate similar to Scotland.',
     'm_yoichi.jpg', (43.187, 140.792), 8.93, 1.55),
    (2, 'Miyagikyo', 'Owned by Nikka  ·  known for softer styles',
     'A cooler valley surrounded by mountains.', 'm_miyagikyo.jpg', (38.308, 140.651), 8.93, 3.95),
    (3, 'Hakushu', 'Owned by Suntory',
     'In a forest at 2,300 ft. Cool, slow maturation.', 'm_hakushu.jpg',
     (35.827, 138.302), 0.85, 1.55),
    (4, 'Yamazaki', 'Owned by Suntory  ·  Japan’s first distillery',
     'Warm, humid and often misty.', 'm_yamazaki.jpg',
     (34.893, 135.675), 0.85, 3.95),
]
CW, CH = 3.55, 2.25
for n, name, owner, cap, photo, (la, lo), cx, cy in cards:
    rrect(s, cx, cy, CW, CH, r=0.22, fill=WHITE, line=HAIR)
    picture(s, A / photo, cx + 0.12, cy + 0.12, CW - 0.24, 0.92, radius_in=0.14)
    badge(cx + 0.38, cy + 1.3, n, 0.3)
    text(s, cx + 0.62, cy + 1.15, CW - 0.8, 0.3, name, size=14, font=SANS, bold=True, color=INK)
    text(s, cx + 0.22, cy + 1.48, CW - 0.34, 0.25, owner, size=9.5, font=SANS, color=MUTE)
    text(s, cx + 0.22, cy + 1.72, CW - 0.4, 0.5, cap, size=12, color=INK, ls=1.08)
    mx, my = pt(la, lo)
    badge(mx, my, n)
# Fukuoka, tonight's distillery
fx, fy = pt(33.59, 130.40)
dot(s, fx, fy, 0.3, MARK_DEEP)
dot(s, fx, fy, 0.12, WHITE)
text(s, fx - 0.35, fy + 0.18, 2.0, 0.28, 'Fukuoka  ·  Hikari', size=11, font=SANS, bold=True, color=INK)
strip(s, 0.85, 6.32, 11.63, 0.5,
      'Fukuoka, where tonight’s whisky is made, runs from 95°F in summer to near freezing in winter. Those swings move the whisky in and out of the wood.',
      size=12)
text(s, 11.48, 6.95, 1.0, 0.3, '08', size=10, font=SANS, color=MUTE, align=PP_ALIGN.RIGHT)
text(s, 0.85, 6.95, 9.0, 0.3, 'Whisky From Japan  ·  The Whiskey Share Society  ·  Map redrawn from Natural Earth (public domain)',
     size=10, font=SANS, color=MUTE)

# ---------------------------------------------------------------- 9 mizunara
s = new_slide()
label(s, 0.8, 'Mizunara oak')
heading(s, 1.22, 'Mizunara is the cask wood most associated with Japanese whisky.', size=28, h=1.0)
picture(s, A / 'mizunara.jpg', 0.85, 2.45, 4.3, 3.95, radius_in=0.22)
text(s, 5.65, 2.45, 6.8, 3.2, [
    [('It is a difficult wood to make casks from.', {'bold': True, 'font': SANS, 'size': 21})],
    'It is porous, so casks leak. It is knotty, so it is hard to work. A tree needs roughly two hundred years before it can be used.',
    'Japanese distillers avoided it until the war and its aftermath cut off imported casks.',
    'It gives sandalwood and incense notes that other oaks do not.',
], size=16.5, ls=1.2, space_after=9)
strip(s, 5.65, 5.45, 6.83, 1.05, [
    [('Tonight’s whisky does not use it.', {'bold': True})],
    'It is aged entirely in ex-sherry casks.'], size=14)
footer(s, 9)

# ---------------------------------------------------------------- 10 what is in the glass (story slide on green)
s = new_slide(INK)
text(s, 0.85, 0.75, 11.6, 0.4, 'What is in your glass', size=15, font=SANS, bold=True, color=CREAM_MUTE)
heading(s, 1.15, 'Hikari Distillery, Fukuoka. Founded 1912.', size=36, color=CREAM, h=0.7)
cols = [
    ('The grain', '100% barley.',
     'One third is saccharified with koji, the mold used for miso and soy sauce. The other two thirds is unmalted.',
     'There is no malted barley in it.'),
    ('The law', 'Not whisky in Japan.',
     'Japan’s Liquor Tax Act defines whisky as made with malted grain. A barley spirit made with koji is shochu.',
     'Rule 3 requires malted grain.'),
    ('The result', 'Sold abroad only.',
     'It began as shochu. The sherry casks made it too dark to sell as shochu.',
     'It is not sold in Japan.'),
]
cw3 = (11.63 - 2 * 0.3) / 3
for i, (lab, lead, body, foot) in enumerate(cols):
    x = 0.85 + i * (cw3 + 0.3)
    rrect(s, x, 2.1, cw3, 3.75, r=0.3, fill=OAK, line=OAK_EDGE)
    text(s, x + 0.32, 2.35, cw3 - 0.6, 0.3, lab, size=13, font=SANS, bold=True, color=CREAM_MUTE)
    text(s, x + 0.32, 2.7, cw3 - 0.5, 0.5, lead, size=22, font=SANS, bold=True, color=CREAM)
    text(s, x + 0.32, 3.35, cw3 - 0.6, 1.6, body, size=15.5, color=CREAM, ls=1.2)
    rect(s, x + 0.34, 4.98, 0.5, 0.035, fill=MARK)
    text(s, x + 0.32, 5.1, cw3 - 0.6, 0.6, foot, size=14.5, font=SANS, bold=True, color=CREAM, ls=1.1)
text(s, 0.85, 6.05, 11.63, 0.5, 'The distillery calls it whisky from Japan, not Japanese whisky.', size=22,
     italic=True, color=CREAM)
footer(s, 10, dark=True)

# ---------------------------------------------------------------- 11 how to taste
s = new_slide()
label(s, 0.8, 'How to taste it')
heading(s, 1.22, 'Four steps.', size=30, h=0.6)
tsteps = [('Look', 'Color tells you about the cask, not the quality.'),
          ('Nose', 'Short sniffs, mouth slightly open. Do not bury your face in it.'),
          ('Taste', 'Small sip. Hold it. Swallow, then breathe out through your nose.'),
          ('Finish', 'What lingers, and for how long? Look past the burn.')]
yy = 2.15
for i, (k, v) in enumerate(tsteps, 1):
    rrect(s, 0.85, yy, 0.46, 0.46, r=0.15, fill=WHITE, line=HAIR)
    text(s, 0.85, yy, 0.46, 0.46, str(i), size=15, font=SANS, bold=True, color=INK, align=PP_ALIGN.CENTER,
         anchor=MSO_ANCHOR.MIDDLE)
    text(s, 1.55, yy - 0.04, 6.8, 0.35, k, size=17, font=SANS, bold=True, color=INK)
    text(s, 1.55, yy + 0.32, 7.1, 0.4, v, size=17, color=INK)
    if i < 4:
        line(s, 1.55, yy + 0.83, 8.2, yy + 0.83, HAIR, 1.0)
    yy += 0.95
strip(s, 0.85, 5.9, 7.35, 0.75, [[('Heat is not flavor. If you score heat, you are just scoring proof.', {'bold': True})]],
      size=14.5)
rrect(s, 8.85, 2.15, 3.63, 4.5, r=0.3, fill=WHITE, line=HAIR)
picture(s, A / 'glencairn.png', 8.85 + (3.63 - 2.23) / 2, 2.4, 2.23, 4.0)
footer(s, 11)

# ---------------------------------------------------------------- 12 flavors
s = new_slide()
label(s, 0.8, 'What you might find')
heading(s, 1.22, 'Fruit, sweetness, wood, and a savory note from the koji.', size=30, h=0.6)
groups = [('Fruit', 'Plum · Dark cherry · Raisin · Green grape · Prune'),
          ('Sweet', 'Caramel · Honey · Chocolate · Candied nuts'),
          ('Wood & spice', 'Oak · Tobacco · Leather · Nutmeg · Clove')]
gw = (11.63 - 2 * 0.25) / 3
for i, (k, v) in enumerate(groups):
    x = 0.85 + i * (gw + 0.25)
    rrect(s, x, 2.1, gw, 1.55, r=0.24, fill=WHITE, line=HAIR)
    text(s, x + 0.3, 2.3, gw - 0.6, 0.35, k, size=14, font=SANS, bold=True, color=MUTE)
    text(s, x + 0.3, 2.68, gw - 0.6, 0.9, v, size=17, color=INK, ls=1.2)
rrect(s, 0.85, 3.95, 11.63, 2.65, r=0.3, fill=WHITE, line=HAIR)
dot(s, 1.27, 4.42, 0.14, MARK_DEEP)
text(s, 1.45, 4.25, 4, 0.35, 'Umami', size=14, font=SANS, bold=True, color=MUTE)
text(s, 1.15, 4.7, 10.9, 0.6, 'Savory and brothy, like soy sauce.', size=30, font=SANS, bold=True, color=INK)
text(s, 1.15, 5.4, 10.9, 1.1, [
    'That taste comes from the koji.',
    'Koji is also what miso and soy sauce are made with.',
], size=17, ls=1.2, space_after=4)
footer(s, 12)


# ---------------------------------------------------------------- 13-15 the three bottles
def bottle_slide(n, glass, name, sub, notes, specs, photo, ph_w, ph_h):
    s = new_slide()
    rrect(s, 0.85, 0.8, 3.1, 5.85, r=0.3, fill=WHITE, line=HAIR)
    picture(s, A / photo, 0.85 + (3.1 - ph_w) / 2, 0.8 + (5.85 - ph_h) / 2, ph_w, ph_h)
    x = 4.45
    text(s, x, 0.8, 8.0, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (glass, {})]], size=15, font=SANS,
         bold=True, color=INK)
    text(s, x, 1.2, 8.0, 0.8, name, size=40, font=SANS, bold=True, color=INK)
    text(s, x, 2.0, 8.0, 0.75, sub, size=17, italic=True, color=MUTE, ls=1.15)
    yy = 2.85
    for k, v in notes:
        text(s, x, yy, 1.4, 0.35, k, size=13, font=SANS, bold=True, color=MUTE)
        text(s, x + 1.4, yy - 0.03, 6.6, 0.7, v, size=16.5, color=INK, ls=1.15)
        yy += 0.86
        if k != 'Finish':
            line(s, x, yy - 0.16, 12.48, yy - 0.16, HAIR, 1.0)
    sw3 = (12.48 - x - 2 * 0.2) / 3
    for i, (k, v) in enumerate(specs):
        bx = x + i * (sw3 + 0.2)
        rrect(s, bx, 5.5, sw3, 1.15, r=0.18, fill=W100)
        text(s, bx + 0.22, 5.6, sw3 - 0.4, 0.3, k, size=11.5, font=SANS, bold=True, color=MUTE)
        text(s, bx + 0.22, 5.9, sw3 - 0.4, 0.7, v, size=13.5, color=INK, ls=1.05)
    footer(s, n)


MASH = ('Mash bill', '100% barley: 1/3 koji, 2/3 unmalted')
bottle_slide(13, 'Glass 1', 'Hakata 10 Year',
             'The youngest of the three. The koji shows most here, because it has had the least time in the cask.',
             [('Nose', 'Plum · Dark cherry · Raisin · Caramel · Oak'),
              ('Palate', 'Soft texture. Raisin, plum, cherry cola, then candied nuts, nutmeg, tobacco leaf and leather.'),
              ('Finish', 'Long. Leather and oak, a slow warmth, several minutes of it.')],
             [MASH, ('Age · proof', '10 Year  ·  84 proof (42%)'), ('Cask · price', 'Ex-sherry  ·  $80 approx.')],
             'hakata10.png', 1.62, 5.3)
bottle_slide(14, 'Glass 2', 'Hakata 12 Year',
             'Two more years in the cask. More sherry, less koji.',
             [('Nose', 'Nutmeg · Cherry · Leather · Tobacco'),
              ('Palate', 'Drier than the 10. More cask, less of the savory note.'),
              ('Finish', 'Medium-long, with a faint salinity several tasters pick up.')],
             [MASH, ('Age · proof', '12 Year  ·  84 proof (42%)'), ('Cask · price', 'Ex-sherry  ·  $100 approx.')],
             'hakata12.png', 1.56, 5.3)
bottle_slide(15, 'Glass 3', 'Hakata 16 Year',
             'The sherry cask leads.',
             [('Nose', 'Nuts · Raisin · Chocolate · Green grape'),
              ('Palate', 'Prune, honey, dark chocolate. The savory note is still there, but fainter.'),
              ('Finish', 'Long, round, gentle.')],
             [MASH, ('Age · proof', '16 Year  ·  84 proof (42%)'), ('Cask · price', 'Ex-sherry  ·  $150 approx.')],
             'hakata16.png', 1.6, 5.3)

# ---------------------------------------------------------------- 16 Sláinte
s = new_slide(INK)
picture(s, A / 'blossom.jpg', (SLIDE_W - 10.15) / 2, 0.55, 10.15, 1.75, radius_in=0.3)
picture(s, LOGO_CREAM, SLIDE_W / 2 - 0.55, 2.5, 1.1, 1.1 * LOGO_RATIO)
text(s, 0.8, 3.4, 11.733, 0.8, 'Sláinte', size=44, font=SANS, bold=True, color=CREAM, align=PP_ALIGN.CENTER,
     anchor=MSO_ANCHOR.MIDDLE)
text(s, 1.6, 4.2, 10.13, 1.7, [
    'The standard exists because whisky made elsewhere was being bottled in Japan and sold as Japanese.',
    'It also excludes Hakata: made in Fukuoka from Kyushu barley and koji, aged up to sixteen years, and labeled for what it is.',
], size=15, italic=True, color=CREAM_MUTE, align=PP_ALIGN.CENTER, ls=1.2, space_after=8)
rrect(s, SLIDE_W / 2 - 3.1, 6.08, 6.2, 0.95, r=0.24, fill=OAK, line=OAK_EDGE)
text(s, SLIDE_W / 2 - 3.1, 6.08, 6.2, 0.95, ['To Hikari Distillery, Fukuoka.', ''], size=19,
     font=SANS, bold=True, color=CREAM, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE, ls=1.1)
