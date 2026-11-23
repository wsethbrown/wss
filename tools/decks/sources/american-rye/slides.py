"""American Rye: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/american-rye <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (the Peat Reek remake is the model). The photographs
are cropped from that deck's slide images (no other copy was kept); their credits are the old
captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PX, PY, PW = 7.85, 0.75, 4.63   # photo panel on the right of a content slide
PH = PW * 1257 / 1056           # the portrait crops are 1056 x about 1260


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, cap, dark=False, ratio=1257 / 1056):
    h = PW * ratio
    picture(s, A / name, PX, PY, PW, h, radius_in=0.26)
    credit(s, PX, PY + h + 0.08, PW, cap, color=CREAM_MUTE if dark else MUTE)


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


def strip(s, y, h, t, size=19):
    """A closing sentence in a light band across the content width."""
    rrect(s, X, y, CW, h, r=0.2, fill=W100)
    text(s, X + 0.3, y, CW - 0.6, h, t, size=size, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)


def pour_slide(n, pour, name, note, maker, style, proof, two_line_name=False, left=None):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / Proof.
    left: draws something else in the placeholder's place (slide 13's mash chart)."""
    s = new_slide()
    if left:
        left(s)
    else:
        bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=21, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.5, r=0.26, fill=WHITE, line=HAIR)
    cols = [('Maker', maker, 2.75), ('Style', style, 3.25), ('Proof', proof, 0.75)]
    cx = x + 0.3
    for label, val, cw_ in cols:
        text(s, cx, 4.85, cw_, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw_, 0.8, val, size=18, color=INK, ls=1.1)
        cx += cw_ + 0.2
    footer(s, n)
    return s


def year_slide(n, year, head, body, quiet, photo, cap, ratio, body_y=4.45, dark=True):
    """The big-year story slide: year, orange rule, heading, body, photo right. dark=True is the
    deck's one green story slide; the other big-year slide sits on paper."""
    s = new_slide(INK if dark else PAPER)
    fg = CREAM if dark else INK
    quiet_c = CREAM_MUTE if dark else MUTE
    text(s, 0.75, 0.6, 6.6, 1.8, year, size=130, font=SANS, bold=True, color=fg, ls=0.9)
    rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK if dark else MARK_DEEP)
    text(s, X, 2.75, 6.7, 1.6, head, size=28, font=SANS, bold=True, color=fg, ls=0.98)
    paras = body if isinstance(body, list) else [body]
    text(s, X, body_y, 6.6, 2.4, paras + [[(quiet, {'color': quiet_c})]],
         size=18.5, color=fg, ls=1.2, space_after=12)
    photo_right(s, photo, cap, dark=dark, ratio=ratio)
    footer(s, n, dark=dark)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 2.95, 6.2, 1.0, 'American Rye', size=60, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.12, 0.9, 0.045, fill=MARK)
text(s, X, 4.35, 6.2, 0.45, '1790s to now  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 4.95, 5.9, 1.5,
     ['How rye became the whiskey of', 'Pennsylvania and Maryland, nearly', 'disappeared, and came back.'],
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 4.95
th = tw * 1287 / 1104
picture(s, A / 'rye-secale-cereale-usda.jpg', 7.53, 0.55, tw, th, radius_in=0.26)
credit(s, 7.53, 0.55 + th + 0.08, tw,
       'Rye, Secale cereale. U.S. Department of Agriculture drawing, public domain.', color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 why rye
s = new_slide()
heading(s, 0.85, 'Why mid-Atlantic farmers grew rye', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('Weather', 'Sown in autumn, it survives a hard winter.'),
    ('Soil', 'It grows on thin, stony, hilly ground.'),
    ('Settlers', 'Germans and Scots-Irish knew it from home.'),
    ('Roads', 'Whiskey kept, and cost less to carry than grain.'),
], label_w=2.4, row_h=1.05, mark=3, label_size=24, size=21)
footer(s, 2)

# ---------------------------------------------------------------- 3 1799 (green story slide)
year_slide(3, '1799', ['Washington’s distillery at', 'Mount Vernon makes almost', '11,000 gallons.'],
                 'His Scottish farm manager, James Anderson, began it with two stills in 1797. '
                 'A stone still house with five\u00a0followed.',
                 'Mash, from the 1798–99 ledgers: 60% rye, 35% corn, 5% malted barley.',
                 'washington-stuart-clark.jpg',
                 'George Washington, by Gilbert Stuart, about 1796–1803. Clark Art Institute, public domain.',
                 1257 / 1056, body_y=4.35)

# ---------------------------------------------------------------- 4 Monongahela and Maryland
# The old slide had no heading; it shows the script's.
s = new_slide()
heading(s, 0.85, 'Pennsylvania and Maryland', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, 'Monongahela',
          ['Western Pennsylvania', 'Mostly rye, little or no corn',
           [('Described as ', {}), ('bold and dry', {'bold': True})]], None),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Maryland',
          ['Baltimore and its farms', 'Some corn in the mash',
           [('Described as ', {}), ('softer and sweeter', {'bold': True})]],
          'The descriptions come from later writers. Few early recipes survive.')]
for (cx, fill, edge, col, name, lines_, note) in sides:
    rrect(s, cx, 2.0, pw, 4.45, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.25, pw - 0.8, 0.75, name, size=34, font=SANS, bold=True, color=col)
    yy = 3.1
    for ln in lines_:
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.4, yy + 0.08, pw - 0.8, 0.6, [ln], size=21, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 0.72
    if note:
        text(s, cx + 0.4, yy + 0.15, pw - 0.8, 0.8, note, size=17, color=CREAM_MUTE, ls=1.15)
rect(s, X + pw + 0.25 + 0.42, 3.0, 0.9, 0.045, fill=MARK)
footer(s, 4)

# ---------------------------------------------------------------- 5 Overholt
s = new_slide()
heading(s, 0.75, ['Overholt: West Overton,', 'then Broad Ford'], size=36, w=7.0, h=1.3)
text(s, X, 2.15, 7.3, 1.6,
     'Abraham Overholt’s family distilled in Westmoreland County, Pennsylvania. His grandson Henry Clay '
     'Frick and Frick’s friend Andrew Mellon became partners. Mellon sold out in 1925.',
     size=18, color=INK, ls=1.2)
aw = 6.6
ah = aw * 365 / 1100
picture(s, A / 'overholt-ad-1897.jpg', X, 4.0, aw, ah, radius_in=0.18)
credit(s, X, 4.0 + ah + 0.08, aw, 'Overholt advertisement, Pacific Wine and Spirit Review, 1897. Public domain.')
fh = 5.5
fw = fh * 912 / 1277
picture(s, A / 'frick-1893.jpg', R - fw, 0.75, fw, fh, radius_in=0.26)
credit(s, R - fw, 0.75 + fh + 0.08, fw, 'Henry Clay Frick, around 1893. Public domain.')
footer(s, 5)

# ---------------------------------------------------------------- 6 pour 1
pour_slide(6, 'Pour 1 of 4', 'Old Overholt',
           ['A Pennsylvania name, made in Kentucky.', 'Beam does not publish the recipe.'],
           'Beam, Kentucky', 'Straight rye, 4 years old', '86')

# ---------------------------------------------------------------- 7 Pikesville
s = new_slide()
heading(s, 0.85, 'Pikesville, the Maryland name that survived', size=40, w=CW, h=0.9)
events = [('1890s', 'Pikesville Rye is first made, north-west of Baltimore.'),
          ('1930s', 'After Repeal, the brand is revived in Baltimore.'),
          ('1972', 'Pikesville is distilled in Maryland for the last time.'),
          ('1982', 'Heaven Hill, in Kentucky, buys the brand.')]
gap = 0.22
cw = (CW - 3 * gap) / 4
for i, (yr, body) in enumerate(events):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.05, cw, 2.95, r=0.26, fill=WHITE, line=HAIR)
    if i == 3:
        rect(s, cx + 0.3, 2.3, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.45, cw - 0.6, 0.75, yr, size=40, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.3, cw - 0.5, 1.6, body, size=18, color=INK, ls=1.2)
strip(s, 5.35, 0.85, 'Pikesville is named after a town just north-west of Baltimore.', size=20)
footer(s, 7)

# ---------------------------------------------------------------- 8 pour 2
pour_slide(8, 'Pour 2 of 4', ['Pikesville', 'Straight Rye'],
           ['Reported to be 51% rye, the legal minimum.',
            'Six years old and 110 proof. Try it neat, then with water.'],
           'Heaven Hill, Kentucky', 'Straight rye, 6 years old', '110', two_line_name=True)

# ---------------------------------------------------------------- 9 1920 (big year, on paper)
year_slide(9, '1920', ['Prohibition shuts the distilleries', 'for almost fourteen years.'],
                 'A few companies were licensed to sell whiskey as medicine, on prescription, from stock '
                 'already in their\u00a0warehouses.',
                 'Old Overholt was one of the medicinal brands.',
                 'pouring-whiskey-sewer-1920.jpg',
                 'Pouring whiskey into a sewer, around 1920. Library of Congress.',
                 1263 / 1056, body_y=3.95, dark=False)

# ---------------------------------------------------------------- 10 after Repeal
s = new_slide()
heading(s, 0.75, 'Rye leaves the east after Repeal', size=40, w=CW, h=0.9)
events = [('1933', 'Repeal, with almost no aged whiskey left.'),
          ('1951', 'Overholt stops distilling at Broad\u00a0Ford.'),
          ('1972', 'Pikesville’s last Maryland batch.'),
          ('1982', 'Pikesville goes to Kentucky.'),
          ('2007', 'Mount Vernon’s rebuilt still house\u00a0opens.')]
g5 = 0.2
c5 = (CW - 4 * g5) / 5
for i, (yr, body) in enumerate(events):
    cx = X + i * (c5 + g5)
    rrect(s, cx, 1.7, c5, 2.0, r=0.22, fill=WHITE, line=HAIR)
    if i == 4:
        rect(s, cx + 0.25, 1.9, 0.8, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.25, 1.98, c5 - 0.5, 0.6, yr, size=30, font=SANS, bold=True, color=INK)
    text(s, cx + 0.25, 2.62, c5 - 0.4, 1.05, body, size=16, color=INK, ls=1.15)
bw = CW
bh = bw * 377 / 2060
picture(s, A / 'bombergers-schaefferstown.jpg', X, 3.95, bw, bh, radius_in=0.2)
credit(s, X, 3.95 + bh + 0.08, bw,
       'Bomberger’s Distillery, Schaefferstown, Pennsylvania, where Michter’s was made until 1989. '
       'Photo: Smallbones, 2011, public domain (CC0).')
footer(s, 10)

# ---------------------------------------------------------------- 11 the rye shelf
s = new_slide()
heading(s, 0.85, 'The rye shelf before the revival', size=40, w=CW, h=0.9)
rows_card(s, X, 1.95, CW, [
    ('Beam', 'Old Overholt (from 1987), Jim Beam Rye'),
    ('Heaven Hill', 'Pikesville (from 1982), Rittenhouse (from 1999)'),
    ('Wild Turkey', 'Wild Turkey Rye'),
    ('Buffalo Trace', 'Sazerac Rye'),
], label_w=3.0, row_h=0.8, label_size=22, size=20)
strip(s, 5.45, 1.0, ['Four Kentucky bourbon distillers.',
                    'Heaven Hill is reported to have distilled rye on one or two days a year.'], size=19)
footer(s, 11)

# ---------------------------------------------------------------- 12 the law
s = new_slide()
heading(s, 0.85, 'What the law requires of rye whisky', size=40, w=CW, h=0.9)
stats = [('51%', 'rye', 'At least, in the\u00a0mash.'),
         ('160', 'proof', 'At most, off the still.'),
         ('125', 'proof', 'At most, into the\u00a0barrel.'),
         ('2', 'years', 'At least, to be called\u00a0straight.')]
for i, (big, label, body) in enumerate(stats):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.0, cw, 3.2, r=0.26, fill=WHITE, line=HAIR)
    if i == 0:
        rect(s, cx + 0.3, 2.25, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.4, cw - 0.6, 1.1, big, size=60, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.3, 3.5, cw - 0.6, 0.5, label, size=22, font=SANS, bold=True, color=MUTE)
    text(s, cx + 0.3, 4.1, cw - 0.5, 1.0, body, size=18, color=INK, ls=1.2)
strip(s, 5.5, 0.85, 'Aged in new charred oak, as bourbon is. The rest of the mash can be any grain.', size=20)
footer(s, 12)


# ---------------------------------------------------------------- 13 pour 3
def mash_card(s):
    """Rye in the mash: the old slide's three bars, in the placeholder's place."""
    x, y, w, h = X, 0.8, 3.4, 5.3
    rrect(s, x, y, w, h, r=0.26, fill=WHITE, line=HAIR)
    text(s, x + 0.3, y + 0.25, w - 0.6, 0.45, 'Rye in the mash', size=19, font=SANS, bold=True, color=INK)
    bars = [('Pikesville', 51, '51%, reported'), ('Old Forester Rye', 65, '65%'), ('Bulleit 95 Rye', 95, '95%')]
    yy = y + 0.95
    bwid = w - 0.6
    for name, v, lab in bars:
        text(s, x + 0.3, yy, bwid, 0.4, name, size=15, font=SANS, bold=True, color=INK)
        rect(s, x + 0.3, yy + 0.45, bwid, 0.24, fill=W100)
        rect(s, x + 0.3, yy + 0.45, bwid * v / 100, 0.24, fill=INK)
        text(s, x + 0.3, yy + 0.76, bwid, 0.4, lab, size=15, color=INK)
        yy += 1.4


pour_slide(13, 'Pour 3 of 4', 'Old Forester Rye',
           ['65% rye, 20% malted barley, 15% corn,', 'as Brown-Forman publishes it.',
            'Compare it with the Pikesville.'],
           'Brown-Forman, Kentucky', 'Kentucky straight rye whisky', '100', left=mash_card)

# ---------------------------------------------------------------- 14 95%
s = new_slide()
text(s, 0.75, 0.6, 6.6, 1.8, '95%', size=130, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK_DEEP)
text(s, X, 2.75, 6.7, 2.0, ['Seagram’s old distillery at', 'Lawrenceburg, Indiana, makes', 'a rye that is almost all rye.'],
     size=28, font=SANS, bold=True, color=INK, ls=0.98)
text(s, X, 4.55, 6.6, 1.0, '95% rye and 5% malted barley, first made for\u00a0blending.',
     size=19, color=MUTE, ls=1.2)
rows_card(s, 7.6, 0.85, R - 7.6, [
    ('1933', 'Seagram buys it.'),
    ('2001', 'Pernod Ricard, after Seagram is broken up.'),
    ('2007', 'Angostura’s parent, as LDI.'),
    ('2011', 'MGP Ingredients, now as Ross & Squibb.'),
], label_w=1.05, row_h=1.25, mark=3, label_size=24, size=17.5)
footer(s, 14)

# ---------------------------------------------------------------- 15 Indiana whiskey
s = new_slide()
heading(s, 0.85, 'Rye brands built on Indiana whiskey', size=40, w=CW, h=0.9)
lw = 5.9
names = ['Bulleit 95 Rye', 'George Dickel Rye', 'Templeton Rye', 'High West, in its blends']
rrect(s, X, 1.95, lw, 0.8 * 4 + 0.1, r=0.26, fill=WHITE, line=HAIR)
yy = 2.0
for i, nm in enumerate(names):
    if i:
        line(s, X + 0.3, yy, X + lw - 0.3, yy, HAIR, 1.0)
    text(s, X + 0.3, yy, lw - 0.6, 0.8, nm, size=22, font=SANS, bold=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    yy += 0.8
gx = X + lw + 0.3
gw = R - gx
rrect(s, gx, 1.95, gw, 3.3, r=0.3, fill=OAK, line=OAK_EDGE)
rect(s, gx + 0.42, 2.3, 0.9, 0.045, fill=MARK)
text(s, gx + 0.42, 2.5, gw - 0.84, 2.6,
     'Templeton was sold with a Prohibition-era Iowa story. Buyers sued in 2014. Under the 2015 settlement '
     'its labels say “distilled\u00a0in\u00a0Indiana”.', size=20, color=CREAM, ls=1.2)
strip(s, 5.55, 0.85, 'A label must name the state of distillation if it differs from the bottler’s address.',
      size=20)
footer(s, 15)

# ---------------------------------------------------------------- 16 pour 4
pour_slide(16, 'Pour 4 of 4', 'Bulleit 95 Rye',
           ['95% rye, distilled in Indiana.',
            'Find that on the back label, then taste it against\u00a0the\u00a0Pikesville.'],
           'Bulleit (Diageo), distilled by MGP', 'Straight rye whiskey', '90')

# ---------------------------------------------------------------- 17 reading the label
s = new_slide()
heading(s, 0.85, 'Reading a rye label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('Rye whisky', 'At least 51% rye, aged in new charred oak.'),
    ('Straight', 'Two years or more, nothing added. Under four years, an\u00a0age\u00a0statement.'),
    ('Distilled in (state)', 'Where it was made, if it was bottled in another state.'),
    ('Mash bill', 'Not required on the label.'),
    (['Monongahela,', 'Maryland style'], 'No legal definition.'),
], label_w=3.4, row_h=0.92, label_size=21, size=19)
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
