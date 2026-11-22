"""Mint Julep (Cocktails, Chapter One): slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I /home/user/wss/tools/decks/build.py <this folder> <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there. The owner's text is kept as written except where
the research outline records a correction.

The two maps (assets/road_map.png, assets/virginia_1789.png) are drawn without any text
from Natural Earth outlines; every label on them is real text placed below, using the
marker positions in road_map.json and virginia_1789.json.
"""
import json

from wsskit import *

SERIES = 'Mint Julep  ·  Cocktails, Chapter One  ·  The Whiskey Share Society'


def jfooter(s, n, dark=False):
    c = CREAM_MUTE if dark else MUTE
    text(s, 0.85, 6.93, 8.5, 0.3, SERIES, size=10, font=SANS, color=c)
    text(s, 11.48, 6.93, 1.0, 0.3, '%02d' % n, size=10, font=SANS, color=c, align=PP_ALIGN.RIGHT)


def head(s, t, sub=None, y=0.75, w=11.6, size=38, color=INK, subcolor=MUTE, x=0.85, h=0.75, sub_h=0.5):
    heading(s, y, t, size=size, color=color, w=w, x=x, h=h)
    if sub:
        text(s, x, y + h + 0.05, w, sub_h, sub, size=18, italic=True, color=subcolor, ls=1.1)


def rows(s, x, y, w, items, label_w=2.6, row_h=0.95, size=16.5, card=True, pad=0.3):
    """The original deck's 'label → text' grammar, as ruled rows in a white card."""
    total = row_h * len(items)
    if card:
        rrect(s, x, y, w, total + 2 * pad - 0.1, r=0.26, fill=WHITE, line=HAIR)
    yy = y + pad
    for i, (label, body) in enumerate(items):
        if i:
            line(s, x + pad, yy - 0.14, x + w - pad, yy - 0.14, HAIR, 1.0)
        text(s, x + pad, yy, label_w - 0.2, row_h - 0.2, label, size=13.5, font=SANS, bold=True, color=INK, ls=1.0)
        text(s, x + pad + label_w, yy - 0.02, w - 2 * pad - label_w, row_h - 0.1, body, size=size, ls=1.18)
        yy += row_h
    return y + total + 2 * pad - 0.1


def glass_line(s, x, y, t, dark=False):
    text(s, x, y, 8, 0.4, [[('●  ', {'color': MARK if dark else MARK_DEEP, 'size': 12}), (t, {})]], size=15,
         font=SANS, bold=True, color=CREAM if dark else INK)


def portrait(s, img, x, y, w, h, caption=None, cap_h=0.9):
    picture(s, A / img, x, y, w, h, radius_in=0.22)
    if caption:
        text(s, x, y + h + 0.12, w, cap_h, caption, size=11, font=SANS, color=MUTE, ls=1.15)


def strip(s, y, runs, h=0.62, dark=False, size=16):
    rrect(s, 0.85, y, 11.63, h, r=0.18, fill=OAK if dark else W100)
    text(s, 1.15, y, 11.0, h, runs, size=size, color=CREAM if dark else INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.12)


def ruled(s, y, items, size=14.5, cpl=62, x=4.45, tx=6.1, tw=6.38):
    """Ruled label/text rows beside a portrait; row height follows the text's line count."""
    import math
    lh = size / 72 * 1.36
    for i, (k, v) in enumerate(items):
        n = max(1, math.ceil(len(v) / cpl))
        if i:
            line(s, x, y - 0.1, 12.48, y - 0.1, HAIR, 1.0)
        text(s, x, y, tx - x - 0.1, 0.4, k, size=13.5, font=SANS, bold=True, color=INK)
        text(s, tx, y - 0.02, tw, n * lh + 0.1, v, size=size, ls=1.13)
        y += n * lh + 0.2
    return y


# ---------------------------------------------------------------- 1 title
title_slide('Mint Julep',
            'The history of the mint julep, with two versions to taste: the brandy original and the bourbon one.',
            series='Cocktails, Chapter One  ·  The Whiskey Share Society')

# ---------------------------------------------------------------- 2 the drink in your hand
s = new_slide()
glass_line(s, 0.85, 0.85, 'Glass A. Pour it now.')
heading(s, 1.35, 'Start with glass A.', size=40, w=6.6, h=0.8)
text(s, 0.85, 2.2, 6.2, 0.9, 'Taste it now. What is in it comes at slide 16.', size=19, italic=True, color=MUTE)
text(s, 0.85, 3.0, 6.2, 0.5, '', size=18, italic=True, color=MUTE)
rrect(s, 7.45, 0.85, 5.03, 5.65, r=0.36, fill=WHITE, line=HAIR)
yy = 1.35
for i, t in enumerate(['Sugar', 'Mint', 'Spirit',
                       'Crushed ice']):
    if i:
        line(s, 7.85, yy - 0.22, 12.08, yy - 0.22, HAIR, 1.0)
    dot(s, 8.0, yy + 0.27, 0.13, MARK_DEEP if i == 3 else INK)
    text(s, 8.3, yy, 3.9, 1.1, t, size=26 if i < 3 else 24, ls=1.05)
    yy += 1.05 if i < 3 else 1.3
jfooter(s, 2)

# ---------------------------------------------------------------- 3 the road to the julep (map)
s = new_slide()
head(s, 'The road to the julep.', 'Where the drink and its name came from.',
     y=0.7, size=36, h=0.65)
mx, my, mw = 0.85, 1.95, 11.63
mp = json.loads((A / 'road_map.json').read_text())
mh = mw * mp['_size'][1] / mp['_size'][0]
picture(s, A / 'road_map.png', mx, my, mw, mh, radius_in=0.26)
rrect(s, mx, my, mw, mh, r=0.26, line=HAIR)


def at(k):
    fx, fy = mp[k]
    return mx + fx * mw, my + fy * mh


labels = [
    ('kentucky', 'Kentucky', 'bourbon, limestone water, ice', 0.98, 2.3, 2.55),
    ('virginia', 'Virginia', 'brandy, sugar, garden mint, drunk at daybreak, 1700s', 3.05, 4.7, 3.0),
    ('england', 'England', 'an apothecary’s syrup, used to hide a bitter dose, 1400s', 8.6, 2.1, 3.3),
    ('andalus', 'Al-Andalus', 'the julep enters Europe', 6.15, 4.85, 2.3),
    ('levant', 'The Levant', 'mint replaces the rose', 9.95, 3.2, 2.4),
    ('persia', 'Persia', 'gulāb: rose petals, sugar, water, prescribed as medicine, c. 900', 9.2, 5.12, 3.12),
]
for k, name, body, lx, ly, lw in labels:
    lh = 0.82 if len(body) > 34 else 0.62
    px, py = at(k)
    cx = min(max(px, lx + 0.2), lx + lw - 0.2)
    cy = ly if py < ly else ly + lh
    line(s, px, py, cx, cy, INK, 1.0)
for k, name, body, lx, ly, lw in labels:
    lh = 0.82 if len(body) > 34 else 0.62
    rrect(s, lx, ly, lw, lh, r=0.12, fill=WHITE, line=HAIR)
    text(s, lx + 0.16, ly + 0.08, lw - 0.3, 0.3, name, size=13, font=SANS, bold=True, color=INK)
    text(s, lx + 0.16, ly + 0.33, lw - 0.3, lh - 0.36, body, size=11.5, italic=True, color=MUTE, ls=1.05)
text(s, 4.4, 5.6, 2.0, 0.35, 'Atlantic', size=13, italic=True, color=MUTE)
text(s, 8.45, 4.42, 1.9, 0.3, 'Mediterranean', size=11, italic=True, color=MUTE)
text(s, 0.85, 6.6, 11.6, 0.3, 'Redrawn from the original deck’s map. Coastlines: Natural Earth (public domain).',
     size=9.5, font=SANS, color=MUTE)

# ---------------------------------------------------------------- 4 it's good for you
s = new_slide()
head(s, 'It’s good for you.', 'For most of its history a julep was a medicine.')
rows(s, 0.85, 2.3, 11.63, [
    ('A julep', 'A sweet liquid that medicine was mixed into. British medical books of the 1700s list camphor juleps, '
                'balsam juleps and juleps with salt.'),
    ('1784', 'A London doctor, writing in Medical Communications, prescribes a mint julep to a woman with a sick '
             'stomach, with an emetic and some powders.'),
    ('Antifogmatic', 'A dram taken before breakfast, meant to keep off damp and fever. The julep was drunk this '
                     'way.'),
], label_w=2.4, row_h=1.3, size=17)
jfooter(s, 4)

# ---------------------------------------------------------------- 5 the paper trail (timeline)
s = new_slide()
head(s, 'The paper trail.', 'The early American references are all from Virginia. None is from Kentucky.', size=38)
stops = [
    ('1770', 'Virginia', 'Munford’s play The Candidates has a drunk character named Mr. Julip. The same year, a hunting poem in the Virginia Gazette.'),
    ('1784', 'Prescription', 'Medical Communications, London: a mint julep prescribed to a patient, with an emetic.'),
    ('1787', 'Rum. No mint.', 'American Museum: the Virginian rises at six and drinks a julep of rum, water and sugar.'),
    ('1793', 'First recipe', 'Rev. Harry Toulmin, in Norfolk: rum and water, well sweetened, with a slip of mint in it.'),
    ('1803', 'Of a morning', 'John Davis, Travels: a dram of spirituous liquor that has mint steeped in it, taken by Virginians of a morning.'),
    ('1807', 'Ice', 'Wig-Wam Gardens, Norfolk, advertises an iced julep.'),
]
x0, ty, cw = 0.85, 3.72, 11.63 / 6
line(s, x0 + 0.12, ty, x0 + 11.63 - 0.05, ty, INK, 1.5)
for i, (yr, tag, body) in enumerate(stops):
    cx = x0 + i * cw
    text(s, cx, 2.35, cw - 0.1, 0.7, yr, size=34, font=SANS, bold=True, color=INK)
    text(s, cx, 3.0, cw - 0.1, 0.4, tag, size=15, italic=True, color=MUTE)
    dot(s, cx + 0.14, ty, 0.24, MARK_DEEP if i == 5 else INK)
    text(s, cx, 4.0, cw - 0.22, 1.9, body, size=13, ls=1.15)
rrect(s, 0.85, 5.92, 11.63, 0.78, r=0.18, fill=W100)
text(s, 1.15, 5.92, 11.0, 0.78, [[('Kentucky was part of Virginia until 1792.  ', {'font': SANS, 'bold': True, 'italic': False, 'size': 16}),
                                   ('The julep was a Virginia drink before Kentucky was a state.', {})]],
     size=16, italic=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
jfooter(s, 5)

# ---------------------------------------------------------------- 6 in 1789 all of this was virginia (map)
s = new_slide()
vp = json.loads((A / 'virginia_1789.json').read_text())
mx, my, mw = 4.15, 0.85, 8.33
mh = mw * vp['_size'][1] / vp['_size'][0]
picture(s, A / 'virginia_1789.png', mx, my, mw, mh, radius_in=0.26)
rrect(s, mx, my, mw, mh, r=0.26, line=HAIR)


def vat(k):
    fx, fy = vp[k]
    return mx + fx * mw, my + fy * mh


heading(s, 0.85, 'In 1789, all of this was Virginia.', size=32, w=3.05, h=1.7)
text(s, 0.85, 2.62, 3.05, 0.85, 'The early julep references come from its south-east corner.', size=16, italic=True,
     color=MUTE, ls=1.12)
rrect(s, 0.85, 3.6, 3.05, 2.88, r=0.22, fill=WHITE, line=HAIR)
text(s, 1.1, 3.8, 2.6, 0.62, 'The Virginia references are all inside the circle.', size=14, font=SANS, bold=True,
     color=INK, ls=1.05)
yy = 4.5
for t in ['Williamsburg 1770', 'Mecklenburg County 1770', 'Norfolk 1793 and 1807']:
    dot(s, 1.17, yy + 0.13, 0.11, MARK_DEEP)
    text(s, 1.35, yy, 2.4, 0.3, t, size=13, color=INK)
    yy += 0.32
text(s, 1.1, 5.55, 2.65, 0.85, 'Kentucky was part of Virginia until 1792.',
     size=12.5, italic=True, color=INK, ls=1.1)
for k, t in [('ohio', 'Ohio'), ('pennsylvania', 'Pennsylvania'), ('maryland', 'Maryland'), ('tennessee', 'Tennessee'),
             ('northcarolina', 'North Carolina'), ('indiana', 'Indiana'), ('illinois', 'Illinois')]:
    px, py = vat(k)
    text(s, px - 0.8, py - 0.13, 1.6, 0.26, t, size=11, font=SANS, color=MUTE, align=PP_ALIGN.CENTER)
px, py = vat('wv')
text(s, px - 0.8, py - 0.13, 1.6, 0.26, 'W. Virginia', size=11, font=SANS, color=CREAM_MUTE, align=PP_ALIGN.CENTER)
px, py = 6.95, 4.05
text(s, px - 1.3, py - 0.38, 2.6, 0.32, 'None from here', size=16, font=SANS, bold=True, color=CREAM,
     align=PP_ALIGN.CENTER)
text(s, px - 1.3, py - 0.04, 2.6, 0.5, 'No julep reference from Kentucky in these years.',
     size=11, italic=True, color=CREAM_MUTE, align=PP_ALIGN.CENTER, ls=1.05)
text(s, 4.15, 6.02, 8.33, 0.3,
     'State outlines from Natural Earth; 1789 Virginia shown as its modern successor states.',
     size=9.5, font=SANS, color=MUTE)
jfooter(s, 6)

# ---------------------------------------------------------------- 7 the virginia julep
s = new_slide()
head(s, 'The Virginia julep.', 'What was in a julep around 1820.')
rows(s, 0.85, 2.25, 11.63, [
    ('Rum', 'Rum had gone out of fashion after the Revolution.'),
    ('Brandy', 'The usual spirit was French brandy, sometimes American peach brandy, sometimes with Spanish or '
               'Portuguese wine added.'),
    ('Fruit and mint', 'Berries in season, and a large bunch of mint on top.'),
    ('Cost', 'It was an expensive drink. Serving one was a way to show wealth and hospitality.'),
], label_w=2.2, row_h=0.98, size=16.5)
jfooter(s, 7)

# ---------------------------------------------------------------- 8 ice, ice, baby
s = new_slide()
head(s, 'Ice, ice, baby.', 'When ice went into the julep.')
rows(s, 0.85, 2.25, 11.63, [
    ('4 May 1807', 'The first known advertisement for an iced julep, placed by the Wig-Wam Gardens in a Norfolk newspaper.'),
    ('1817', 'Orsamus Willard of the City Hotel, New York, learns the iced julep from a visiting Virginian. '
             'It spreads from there.'),
    ('1830s', 'New York bartenders crush ice with a mallet. The result is called a hailstorm julep.'),
], label_w=2.2, row_h=0.98, size=16.5)
text(s, 0.85, 5.88, 11.6, 0.9, ['By the 1830s the julep was an iced drink in New York as well as Virginia.'],
                              
     size=19, italic=True, color=INK, ls=1.15)
jfooter(s, 8)

# ---------------------------------------------------------------- 9 wholly american
s = new_slide()
head(s, 'Wholly American.', 'The best-known julep makers of the 1800s were Black men, free and enslaved.')
people = [
    ('Cato Alexander', 'New York',
     [[('Freed in 1799. Kept a tavern four miles up the Harlem Road for about thirty years, among the most '
        'fashionable in the country. He served ', {}), ('brandy', {'bold': True}), (' juleps.', {})]]),
    ('Jasper Crouch', 'Richmond',
     'A free man of color. Called the first master of the julep. Chief Justice John Marshall drank his.'),
    ('Carter', 'Washington',
     'Kept the “Hole in the Wall” bar inside the United States Capitol.'),
    ('Tom Bullock', 'St. Louis',
     'Wrote The Ideal Bartender (1917), the first cocktail book by a Black author in America. He is on slide 12.'),
]
cw, ch = 5.7, 2.15
for i, (name, place, body) in enumerate(people):
    cx = 0.85 + (i % 2) * (cw + 0.23)
    cy = 2.2 + (i // 2) * (ch + 0.15)
    rrect(s, cx, cy, cw, ch, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.32, cy + 0.24, cw - 0.6, 0.45, [[(name, {}), ('   ' + place, {'size': 13, 'bold': False, 'color': MUTE})]],
         size=21, font=SANS, bold=True, color=INK)
    text(s, cx + 0.32, cy + 0.78, cw - 0.6, ch - 0.9, body, size=14.5, ls=1.18)
jfooter(s, 9)

# ---------------------------------------------------------------- 10 the prince's julep (green story slide)
s = new_slide(INK)
text(s, 0.85, 0.85, 7.0, 0.4, 'Richmond, October 1860. The Ballard House and Exchange Hotel.', size=15, font=SANS,
     bold=True, color=CREAM_MUTE)
heading(s, 1.3, 'The Prince’s julep.', size=42, color=CREAM, w=7.0, h=0.85)
text(s, 0.85, 2.35, 6.75, 3.3, [
    'The Prince of Wales, nineteen, the future Edward VII, is told Richmond holds the best compounder of cooling '
    'drinks in the world.',
    'What Jim Cook makes takes more than three hundred words to describe in the published record of the royal tour: '
    'basins and obelisks of ice drilled through for straws, a tumbler holding a pint and a half, and flowers on top.',
    'He takes one sip and asks for the recipe. He finishes it, his party drains a second, and a third is booked '
    'for the following morning.',
], size=16, color=CREAM, ls=1.2, space_after=10)
text(s, 0.85, 5.75, 6.75, 0.85, 'The story goes that, years later, it was the one thing he remembered about '
     'Richmond.', size=17, italic=True, color=CREAM, ls=1.15)
rrect(s, 8.1, 0.85, 4.38, 5.65, r=0.4, fill=OAK, line=OAK_EDGE)
rect(s, 8.6, 1.5, 0.9, 0.045, fill=MARK)
text(s, 8.6, 1.75, 3.5, 1.7, '13', size=110, font=SANS, bold=True, color=CREAM, ls=0.9)
text(s, 8.6, 3.5, 3.5, 1.3, 'straws in the third julep, one for each of the royal party drinking from it at once.',
     size=19, italic=True, color=CREAM, ls=1.18)
text(s, 8.6, 5.15, 3.5, 1.0, 'Visit of His Royal Highness the Prince of Wales … in the Year 1860 (Toronto, 1861).',
     size=11, font=SANS, color=CREAM_MUTE, ls=1.15)
jfooter(s, 10, dark=True)

# ---------------------------------------------------------------- 11 john dabney
s = new_slide()
portrait(s, 'dabney.jpg', 0.85, 0.85, 3.2, 4.0)
text(s, 0.85, 4.98, 3.2, 0.62, ['He could not read.', ''], size=13, italic=True,
     color=MUTE, ls=1.1)
text(s, 0.85, 5.6, 3.2, 0.42, 'The only known photograph of John Dabney. The Valentine, Richmond.', size=9.5,
     font=SANS, color=MUTE, ls=1.1)
heading(s, 0.8, 'John Dabney', size=38, x=4.45, w=8.0, h=0.7)
text(s, 4.45, 1.5, 8.0, 0.4, 'c. 1824–1900  ·  Richmond, Virginia', size=17, italic=True, color=MUTE)
ruled(s, 2.02, [
    ('Born enslaved', 'Hanover County, about 1824. He was small, so he was made a jockey. When he grew too big he '
                      'was put to work in a kitchen.'),
    ('The ice', 'He shaved it with a carpenter’s plane turned blade-up, with wooden sides to catch the shavings.'),
    ('Elizabeth', 'He bought his wife’s freedom with tips, because her owners were preparing to sell her away from him.'),
    ('The debt', 'He was still paying for his own freedom when Emancipation ended the debt. He paid the rest '
                 'anyway.'),
    ('The recipe', 'Crushed ice, sugar, mint bruised with the ice, then brandy. Not bourbon.'),
], size=14.5, cpl=62)
strip(s, 6.12, [[('The most celebrated julep maker of his time made it with brandy.', {'bold': True})]], h=0.6)
jfooter(s, 11)

# ---------------------------------------------------------------- 12 the six-cent julep
s = new_slide()
portrait(s, 'bullock.jpg', 0.85, 0.85, 3.2, 4.0)
text(s, 0.85, 4.98, 3.2, 0.35, 'Tom Bullock', size=16, font=SANS, bold=True, color=INK)
text(s, 0.85, 5.3, 3.2, 0.62, ['St. Louis Country Club', 'The Ideal Bartender, 1917'], size=13, italic=True,
     color=MUTE, ls=1.1)
heading(s, 0.8, 'The six-cent julep.', size=38, x=4.45, w=8.0, h=0.7)
text(s, 4.45, 1.5, 8.0, 0.4, 'Roosevelt v. Newett  ·  Marquette, Michigan  ·  May 1913', size=17, italic=True,
     color=MUTE)
ruled(s, 2.02, [
    ('1912', 'The Iron Ore, a Michigan newspaper, prints that Roosevelt gets drunk, and not infrequently, and that '
             'all his intimates know it. Roosevelt sues for libel.'),
    ('May 1913', 'On the stand he swears he has never been intoxicated. He admits there was a mint bed at the White '
                 'House. He says that since leaving office he drank part of one julep, at the St. Louis Country '
                 'Club.'),
    ('The rebuttal', 'The St. Louis Post-Dispatch asks who was ever known to drink just part of one of Tom’s. '
                     'It calls Bullock the greatest mixologist “of any race, color or condition of servitude.”'),
    ('The verdict', 'Newett cannot produce a witness and withdraws. Roosevelt wins and asks for the smallest damages the law allows.'),
], size=13.5, cpl=68)
rrect(s, 0.85, 6.08, 11.63, 0.74, r=0.18, fill=W100)
dot(s, 1.38, 6.45, 0.56, WHITE)
text(s, 1.09, 6.25, 0.58, 0.4, '6¢', size=19, font=SANS, bold=True, color=INK, align=PP_ALIGN.CENTER,
     anchor=MSO_ANCHOR.MIDDLE)
text(s, 1.9, 6.08, 10.4, 0.74, [[('Roosevelt was awarded six cents.', {'bold': True})],
                               [('Bullock printed the editorial at the front of his book.', {'italic': True})]],
     size=14, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.1)
jfooter(s, 12)

# ---------------------------------------------------------------- 13 damn the excise
s = new_slide()
glass_line(s, 0.85, 0.85, 'Glass B. Pour it now.')
heading(s, 1.3, 'Damn the excise.', size=38, w=5.4, h=0.75)
text(s, 0.85, 2.05, 5.4, 0.75, 'In 1791 Congress put a tax on American-made spirits.',
     size=16, italic=True, color=MUTE, ls=1.12)
yy = 2.8
for k, v in [('Pennsylvania', 'Farmers take up arms. Washington leads about 13,000 militia against them.'),
             ('Kentucky', 'Does not pay. For four years grand juries will not indict, informers will not come '
                          'forward and lawyers will not prosecute.'),
             ('1802', 'Jefferson repeals the tax.')]:
    text(s, 0.85, yy, 5.4, 0.35, k, size=14, font=SANS, bold=True, color=INK)
    text(s, 0.85, yy + 0.32, 5.4, 0.75, v, size=14, ls=1.12)
    yy += 1.32 if k == 'Kentucky' else 0.97
picture(s, A / 'whiskey_rebellion.jpg', 6.73, 0.85, 5.75, 3.66, radius_in=0.22)
text(s, 6.73, 4.6, 5.75, 0.6, 'Washington reviews the army raised to put down the Whiskey Rebellion, 1794. '
     'Attributed to Frederick Kemmelmeyer. The Metropolitan Museum of Art, public domain.',
     size=10.5, font=SANS, color=MUTE, ls=1.12)
strip(s, 6.1, [[('Distillers did not move to Kentucky to escape the tax. It was a federal tax, and Kentucky did not pay it.',
                  {'bold': True})]], h=0.66, size=15)
jfooter(s, 13)

# ---------------------------------------------------------------- 14 the julep goes out of style
s = new_slide()
head(s, 'The julep goes out of style.', 'Why bars stopped making it.')
rows(s, 0.85, 2.25, 11.63, [
    ('Too slow', 'The ice is crushed by hand and the garnish is built for each drink.'),
    ('Too strong', 'It is nearly all spirit and ice.'),
    ('Too old', 'Newer drinks were lighter and quicker to make: fizzes, Collinses, coolers.'),
], label_w=2.2, row_h=0.9, size=17)
text(s, 0.85, 5.55, 11.6, 0.8, 'It became an old-fashioned drink, made for occasions.',
     size=21, italic=True, color=INK, ls=1.15)
jfooter(s, 14)

# ---------------------------------------------------------------- 15 the woman who drank it all
s = new_slide()
portrait(s, 'modjeska.jpg', 0.85, 0.85, 3.2, 4.0)
text(s, 0.85, 4.98, 3.2, 0.35, 'Helena Modjeska', size=16, font=SANS, bold=True, color=INK)
text(s, 0.85, 5.3, 3.2, 0.62, ['Polish actress', ''], size=13,
     italic=True, color=MUTE, ls=1.1)
heading(s, 0.8, 'The woman who drank it all.', size=38, x=4.45, w=8.0, h=0.7)
text(s, 4.45, 1.5, 8.0, 0.4, 'Louisville, 1877. A story, not a documented event.', size=17, italic=True, color=MUTE)
text(s, 4.45, 2.1, 8.0, 1.3, 'Meriwether Lewis Clark Jr., grandson of William Clark, has built Churchill Downs and '
     'planted mint behind the clubhouse. He hands the visiting actress a very large julep, meant to be passed around '
     'the table.', size=16, ls=1.2)
text(s, 4.45, 3.45, 8.0, 0.45, 'She drinks the whole thing herself.', size=22, font=SANS, bold=True, color=INK)
text(s, 4.45, 3.92, 8.0, 0.45, [[('●  ', {'color': MARK_DEEP, 'size': 14}), ('Then she asks for more.', {})]], size=22,
     font=SANS, bold=True, color=INK)
text(s, 4.45, 4.6, 8.0, 1.2, 'The Kentucky Derby’s julep tradition is traced to this story. Modjeska learned '
     'English at thirty-six and became one of the leading Shakespearean actresses in America.',
     size=14.5, color=MUTE, ls=1.18)
rrect(s, 0.85, 6.02, 11.63, 0.76, r=0.18, fill=W100)
text(s, 1.15, 6.02, 11.0, 0.76, [[('In 1883 she gave the first American performance of an Ibsen play, in Louisville.', {'bold': True})],
                                 [('In 1889 a Louisville candymaker named a sweet after her. Modjeskas are still sold.', {'italic': True})]],
     size=14, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.1)
jfooter(s, 15)

# ---------------------------------------------------------------- 16 two juleps
s = new_slide()
head(s, 'Two juleps.', 'The two glasses from tonight.')
cards = [
    (0.85, WHITE, INK, MUTE, 'Glass A  ·  c. 1820  ·  Virginia', 'The Virginia julep', 'as described around 1820',
     'Cognac + peach brandy', ['1½ oz cognac  ·  ½ oz peach brandy', '¼ oz simple syrup  ·  8 mint leaves',
                               'berries in season, buried in the ice', 'crushed ice, mounded high']),
    (6.78, INK, CREAM, CREAM_MUTE, 'Glass B  ·  c. 1900  ·  Kentucky', 'The Kentucky julep', 'as made around 1900',
     'Bourbon', ['2 oz bourbon', '¼ oz simple syrup  ·  8 mint leaves', '', 'crushed ice, mounded high']),
]
for x, fill, fg, mu, meta, name, tag, spirit, lines in cards:
    rrect(s, x, 2.2, 5.7, 3.6, r=0.3 if fill == INK else 0.26, fill=fill, line=None if fill == INK else HAIR)
    text(s, x + 0.4, 2.45, 5.0, 0.3, meta, size=12.5, font=SANS, bold=True, color=mu)
    text(s, x + 0.4, 2.8, 5.0, 0.55, name, size=26, font=SANS, bold=True, color=fg)
    text(s, x + 0.4, 3.35, 5.0, 0.35, tag, size=14, italic=True, color=mu)
    rect(s, x + 0.42, 3.85, 0.7, 0.04, fill=MARK if fill == INK else MARK_DEEP)
    text(s, x + 0.4, 4.0, 5.0, 0.45, spirit, size=20, font=SANS, bold=True, color=fg)
    text(s, x + 0.4, 4.5, 5.0, 1.3, [l for l in lines if l], size=14.5, color=fg, ls=1.15)
strip(s, 5.98, [[('Brandy became scarce and expensive after the Civil War and the vine blight in France.', {'bold': True})],
                [('Bourbon was cheaper and made nearby.', {'italic': True})]], h=0.8, size=14.5)
jfooter(s, 16)

# ---------------------------------------------------------------- 17 building it at home
s = new_slide()
head(s, 'Building it at home.', 'Two recipes and two rules.')
for x, name, body in [
    (0.85, 'Kentucky julep', '8 mint leaves  ·  ¼ oz simple syrup  ·  2 oz bourbon. Wipe the mint round a chilled cup, '
                             'add syrup and bourbon, pack with crushed ice and stir until the cup frosts. Mound more '
                             'ice on top. Finish with a large sprig of mint and a short straw.'),
    (6.78, 'Virginia julep', 'Same build, but 1½ oz cognac and ½ oz peach brandy instead of the bourbon, and a berry '
                             'or two buried in the ice.'),
]:
    rrect(s, x, 2.2, 5.7, 2.35, r=0.26, fill=WHITE, line=HAIR)
    text(s, x + 0.35, 2.42, 5.0, 0.4, name, size=18, font=SANS, bold=True, color=INK)
    text(s, x + 0.35, 2.88, 5.0, 1.6, body, size=15, ls=1.18)
for i, (k, v) in enumerate([('Rule one', 'Use crushed ice, not cubes. The drink is meant to dilute as you drink it.'),
                            ('Rule two', 'Bruise the mint. Do not grind it: ground mint tastes bitter.')]):
    y = 4.85 + i * 0.85
    rrect(s, 0.85, y, 0.5, 0.5, r=0.13, fill=W100)
    text(s, 0.85, y, 0.5, 0.5, str(i + 1), size=16, font=SANS, bold=True, color=INK, align=PP_ALIGN.CENTER,
         anchor=MSO_ANCHOR.MIDDLE)
    text(s, 1.6, y + 0.07, 10.8, 0.7, v, size=17, ls=1.12)
jfooter(s, 17)

# ---------------------------------------------------------------- 18 Sláinte
s = new_slide(INK)
picture(s, LOGO_CREAM, SLIDE_W / 2 - 0.9, 0.35, 1.8, 1.8 * LOGO_RATIO)
text(s, 0.8, 1.98, 11.733, 0.95, 'Sláinte', size=54, font=SANS, bold=True, color=CREAM, align=PP_ALIGN.CENTER,
     anchor=MSO_ANCHOR.MIDDLE)
rect(s, SLIDE_W / 2 - 0.45, 3.0, 0.9, 0.045, fill=MARK)
text(s, 1.8, 3.25, 9.733, 1.95, ['It began as a rose-water medicine in Persia.',
                                 'It became a brandy drink in Virginia, made famous by men who were not free.',
                                 'It became a bourbon drink in Kentucky.'],
     size=18, color=CREAM_MUTE, align=PP_ALIGN.CENTER, ls=1.2)
text(s, 1.8, 5.35, 9.733, 0.85, ['Every drink you like has a story like this.',
                                 'Most of them just haven’t been written down.'],
     size=20, italic=True, color=CREAM, align=PP_ALIGN.CENTER, ls=1.2)
text(s, 0.8, 6.55, 11.733, 0.35, 'The Whiskey Share Society', size=11, font=SANS, color=CREAM_MUTE, align=PP_ALIGN.CENTER)
