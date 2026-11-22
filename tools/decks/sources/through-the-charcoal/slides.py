"""Through the Charcoal: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/through-the-charcoal <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (Rye Country and The Long Way Back are the models).
The photographs are cropped from that deck's slide images (no other copy was kept); their
credits are the old captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PX, PY, PW = 7.85, 0.75, 4.63   # photo panel on the right of a content slide
NB = ' '            # non-breaking space, to keep a last word company


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, cap, ratio, dark=False):
    """A photo crop on the right, at its own aspect ratio, with its credit under it."""
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


def pour_slide(n, pour, name, note, maker, style, proof, two_line_name=False,
               widths=(3.0, 2.8, 0.75), val_size=18):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / Proof."""
    s = new_slide()
    bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=21, italic=True, color=INK, ls=1.2)
    rrect(s, x, 4.6, w, 1.5, r=0.26, fill=WHITE, line=HAIR)
    cx = x + 0.3
    for (label, val), cw_ in zip([('Maker', maker), ('Style', style), ('Proof', proof)], widths):
        text(s, cx, 4.85, cw_, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw_, 0.8, val, size=val_size, color=INK, ls=1.1)
        cx += cw_ + 0.2
    footer(s, n)
    return s


def year_slide(n, year, head, body, photo, cap, ratio, quiet=None, body_y=4.45, dark=True):
    """The big-year story slide: year, orange rule, heading, body, photo right. dark=True is the
    deck's one green story slide; the other big-year slide with a photo sits on paper."""
    s = new_slide(INK if dark else PAPER)
    fg = CREAM if dark else INK
    quiet_c = CREAM_MUTE if dark else MUTE
    text(s, 0.75, 0.6, 6.6, 1.8, year, size=130, font=SANS, bold=True, color=fg, ls=0.9)
    rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK if dark else MARK_DEEP)
    text(s, X, 2.75, 6.7, 1.6, head, size=28, font=SANS, bold=True, color=fg, ls=0.98)
    paras = body if isinstance(body, list) else [body]
    if quiet:
        paras = paras + [[(quiet, {'color': quiet_c})]]
    text(s, X, body_y, 6.6, 2.4, paras, size=18.5, color=fg, ls=1.2, space_after=12)
    photo_right(s, photo, cap, ratio, dark=dark)
    footer(s, n, dark=dark)
    return s


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.65, 2.0, 2.0 * LOGO_RATIO)
text(s, X, 2.45, 6.5, 1.75, ['Through the', 'Charcoal'], size=56, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.3, 0.9, 0.045, fill=MARK)
text(s, X, 4.5, 6.2, 0.45, 'Tennessee whiskey  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 5.05, 6.0, 1.5,
     ['How Tennessee whiskey is made, and Nearest', 'Green, the enslaved distiller who taught',
      'Jack Daniel.'],
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 4.95
th = tw * 1230 / 1104
picture(s, A / 'charcoal-ricks-postcard.jpg', 7.53, 0.55, tw, th, radius_in=0.26)
credit(s, 7.53, 0.55 + th + 0.08, tw,
       ['Burning maple for charcoal at the Jack Daniel Distillery, Lynchburg.',
        'Mid-century postcard, public domain.'], color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 maple charcoal
s = new_slide()
heading(s, 0.85, 'Maple charcoal, between the still and the' + NB + 'barrel', size=36, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('Maple', 'sugar maple, stacked and burned in the open'),
    ('Charcoal', 'broken up and packed about ten feet deep'),
    ('New spirit', 'dripped through it, slowly'),
    ('Barrel', 'filled after the charcoal, not before'),
], label_w=2.6, row_h=1.05, mark=3, label_size=24, size=22)
footer(s, 2)

# ---------------------------------------------------------------- 3 Lincoln County Process
s = new_slide()
heading(s, 0.85, 'Called the Lincoln County Process', size=40, w=CW, h=0.9)
text(s, X, 1.75, CW, 0.5, 'Lynchburg’s county, Moore, was carved partly out of Lincoln County in 1871.',
     size=21, color=MUTE)
rows_card(s, X, 2.55, CW, [
    ('What it does', 'The charcoal takes some of the oils and heavier flavours out of the new spirit.'),
    ('What is argued', 'How much of that difference is still there after four years in' + NB + 'oak.'),
    ('Who started it', 'Nobody knows. Several names are put forward and none is' + NB + 'proved.'),
], label_w=3.1, row_h=1.2, label_size=23, size=21)
footer(s, 3)

# ---------------------------------------------------------------- 4 Dan Call's farm
s = new_slide()
heading(s, 0.85, 'Dan Call’s farm, near Lynchburg, around' + NB + '1860', size=36, w=CW, h=0.9)
gap = 0.25
cw3 = (CW - 2 * gap) / 3
people = [('Dan Call', 'Storekeeper, preacher and distiller. He owned the' + NB + 'still.'),
          ('Nathan “Nearest” Green',
           'Enslaved. Later research says he was owned by Landis & Green and hired out to' + NB + 'Call.'),
          ('Jack Daniel', 'Still a boy, working for Call. Green taught him to make' + NB + 'whiskey.')]
for i, (name, body) in enumerate(people):
    cx = X + i * (cw3 + gap)
    rrect(s, cx, 2.0, cw3, 3.0, r=0.26, fill=WHITE, line=HAIR)
    if i == 1:
        rect(s, cx + 0.35, 2.25, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.35, 2.4, cw3 - 0.45, 0.55, name, size=20, font=SANS, bold=True, color=INK)
    text(s, cx + 0.35, 3.05, cw3 - 0.6, 1.9, body, size=19, color=INK, ls=1.2)
strip(s, 5.4, 0.85, 'Most of this rests on a 1967 biography and oral tradition. The written trail is thin.',
      size=20)
footer(s, 4)

# ---------------------------------------------------------------- 5 1866 (the green story slide)
year_slide(5, '1866', ['The date on every bottle', 'of Jack Daniel’s'],
           'His biographer, Peter Krass, puts the start of Daniel’s own business at 1875. His year of '
           'birth is disputed' + NB + 'too.',
           'jack-daniel-portrait.jpg', 'Jasper Newton “Jack” Daniel. Public domain.', 1284 / 1056,
           body_y=4.0)

# ---------------------------------------------------------------- 6 after 1865
s = new_slide()
heading(s, 0.85, ['After 1865, Green', 'worked for Daniel', 'as a free man.'], size=36, w=4.6, h=1.9)
text(s, X, 3.05, 4.3, 2.6,
     'His sons George and Eli worked for Daniel too. No photograph of Nearest Green is known to'
     + NB + 'survive.', size=20, color=INK, ls=1.25)
pw6 = R - 5.75
ph6 = pw6 * 794 / 1340
picture(s, A / 'jack-daniel-with-workers.jpg', 5.75, 0.95, pw6, ph6, radius_in=0.26)
credit(s, 5.75, 0.95 + ph6 + 0.1, pw6,
       ['Jack Daniel, in the white hat, with distillery workers. Undated.',
        'Jack Daniel’s says it has reason to believe the man on the left is Green’s son George. '
        'Public domain.'])
footer(s, 6)

# ---------------------------------------------------------------- 7 pour 1
pour_slide(7, 'Pour 1 of 4', ['Jack Daniel’s', 'Old No. 7'],
           'Before anything else, notice the weight of it in your mouth. The charcoal is meant to make it'
           + NB + 'lighter.',
           ['Jack Daniel Distillery,', 'Lynchburg'], 'Tennessee whiskey', '80', two_line_name=True)

# ---------------------------------------------------------------- 8 1910 (big year, on paper)
year_slide(8, '1910', ['Tennessee bans making whiskey,', 'ten years before the rest', 'of the country.'],
           'The legislature passed it in 1909 over the veto of Governor Malcolm' + NB + 'Patterson.',
           'malcolm-patterson.jpg', 'Malcolm R. Patterson, governor of Tennessee 1907–1911. Public domain.',
           1284 / 1056, body_y=4.55, dark=False)

# ---------------------------------------------------------------- 9 Lynchburg 1907 to 1938
s = new_slide()
heading(s, 0.85, 'Lynchburg from 1907 to 1938', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('1907', 'Jack Daniel hands the business to his nephew, Lem Motlow.'),
    ('1910', 'State prohibition. Lynchburg stops distilling.'),
    ('1911', 'Jack Daniel dies.'),
    ('1933', 'National Repeal. Tennessee stays dry.'),
    ('1938', 'Motlow reopens the distillery.'),
], label_w=1.3, row_h=0.68, mark=4, label_size=26, size=20)
strip(s, 5.55, 0.8, 'For 28 years no legal whiskey was made in Lynchburg.', size=20)
footer(s, 9)

# ---------------------------------------------------------------- 10 George Dickel
s = new_slide()
fh = 5.5
fw = fh * 888 / 1284
heading(s, 0.85, ['George Dickel, a', 'Nashville merchant'], size=40, w=R - fw - X - 0.4, h=1.5)
text(s, X, 2.6, R - fw - X - 0.5, 3.5,
     ['From 1888 his firm was sole distributor of the Cascade distillery near Tullahoma.',
      'He sold it and put his name on it. He did not distil' + NB + 'it.',
      [('Schenley revived the brand at a new distillery in' + NB + '1959.', {'color': MUTE})]],
     size=21, color=INK, ls=1.2, space_after=14)
picture(s, A / 'george-dickel-giers.jpg', R - fw, 0.75, fw, fh, radius_in=0.26)
credit(s, R - fw, 0.75 + fh + 0.08, fw, 'George A. Dickel, photographed by Carl Giers, Nashville. Public domain.')
footer(s, 10)

# ---------------------------------------------------------------- 11 pour 2
pour_slide(11, 'Pour 2 of 4', ['George Dickel', 'Signature Recipe'],
           'The same process at another distillery. Compare it with the Jack Daniel’s for sweetness and'
           + NB + 'weight.',
           ['Cascade Hollow Distilling', 'Co., Tullahoma'], 'Tennessee whisky', '90', two_line_name=True)

# ---------------------------------------------------------------- 12 the 2013 law
s = new_slide()
heading(s, 0.85, 'Tennessee whiskey in state law, 2013', size=40, w=CW, h=0.9)
stats = [('51', '% corn', 'At least, in the' + NB + 'mash.'),
         ('160', 'proof', 'The most it can come off the' + NB + 'still.'),
         ('125', 'proof', 'The most it can go into the' + NB + 'barrel.'),
         ('80', 'proof', 'The least it can be bottled' + NB + 'at.'),
         ('1', 'extra step', 'Maple charcoal, before the' + NB + 'barrel.')]
g5 = 0.2
c5 = (CW - 4 * g5) / 5
for i, (big, label, body) in enumerate(stats):
    cx = X + i * (c5 + g5)
    rrect(s, cx, 1.95, c5, 3.2, r=0.24, fill=WHITE, line=HAIR)
    if i == 4:
        rect(s, cx + 0.28, 2.18, 0.8, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.28, 2.3, c5 - 0.5, 1.0, big, size=54, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.28, 3.3, c5 - 0.5, 0.45, label, size=20, font=SANS, bold=True, color=MUTE)
    text(s, cx + 0.28, 3.85, c5 - 0.45, 1.25, body, size=17, color=INK, ls=1.2)
strip(s, 5.45, 1.0, 'Made and aged in Tennessee, in new charred oak. Prichard’s, in Kelso, is exempt from the '
      'charcoal' + NB + 'rule.', size=20)
footer(s, 12)

# ---------------------------------------------------------------- 13 bourbon and Tennessee whiskey
# The old slide had two column titles and no heading; it shows the script's.
s = new_slide()
heading(s, 0.85, 'Bourbon and Tennessee whiskey', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, MUTE, 'Bourbon',
          ['51% corn or more', 'New charred oak barrels', 'Can be made anywhere in the US'], None),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, CREAM_MUTE, 'Tennessee whiskey',
          ['51% corn or more', 'New charred oak barrels',
           [[('Made in Tennessee,', {})], [('through maple charcoal', {'bold': True})]]],
          'NAFTA (1994) and the USMCA call it a straight bourbon made only in Tennessee.')]
for (cx, fill, edge, col, quiet, name, lines_, note) in sides:
    rrect(s, cx, 1.95, pw, 4.72, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.2, pw - 0.8, 0.75, name, size=34, font=SANS, bold=True, color=col)
    yy = 3.05
    for ln in lines_:
        paras = ln if (isinstance(ln, list) and isinstance(ln[0], list)) else [ln]
        rh = 0.72 if len(paras) == 1 else 1.02
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.4, yy + 0.08, pw - 0.8, rh - 0.12, paras, size=21, color=col, anchor=MSO_ANCHOR.MIDDLE,
             ls=1.1)
        yy += rh
    if note:
        text(s, cx + 0.4, yy + 0.15, pw - 0.8, 0.9, note, size=17, color=quiet, ls=1.15)
rect(s, X + pw + 0.25 + 0.42, 2.95, 0.9, 0.045, fill=MARK)
footer(s, 13)

# ---------------------------------------------------------------- 14 pour 3
pour_slide(14, 'Pour 3 of 4', 'Buffalo Trace',
           ['A Kentucky bourbon with no charcoal step.', 'Taste it beside the Dickel, which is the same proof.'],
           ['Buffalo Trace,', 'Frankfort, Kentucky'], ['Kentucky straight', 'bourbon'], '90')

# ---------------------------------------------------------------- 15 2016 (big year, on paper)
s = new_slide()
text(s, 0.75, 0.55, 8.0, 2.1, '2016', size=150, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 2.75, 1.2, 0.045, fill=MARK_DEEP)
text(s, X, 3.0, CW, 0.7, 'The New York Times reports on Nearest Green, June' + NB + '2016.',
     size=30, font=SANS, bold=True, color=INK, ls=0.98)
text(s, X, 3.95, CW, 2.2,
     ['Jack Daniel’s put his story forward for its 150th anniversary. Fawn Weaver read the article and began '
      'researching his' + NB + 'life.',
      [('The company now names Green as its first master distiller.', {'color': MUTE})]],
     size=22, color=INK, ls=1.2, space_after=14)
footer(s, 15)

# ---------------------------------------------------------------- 16 supported and thin
s = new_slide()
heading(s, 0.85, 'What the record supports, and where it is' + NB + 'thin', size=36, w=CW, h=0.9)
pw16 = (CW - 0.25) / 2
cols = [('Supported', ['Green was enslaved and worked a still near Lynchburg.',
                       'He taught the young Jack Daniel.',
                       'Jack Daniel’s calls him its first master distiller.'], False),
        ('Thin', ['His dates of birth and death.',
                  'What exactly he taught.',
                  'That charcoal mellowing came from West' + NB + 'Africa.'], True)]
for i, (name, items, marked) in enumerate(cols):
    cx = X + i * (pw16 + 0.25)
    rrect(s, cx, 1.8, pw16, 3.6, r=0.28, fill=WHITE, line=HAIR)
    text(s, cx + 0.4, 1.98, pw16 - 0.8, 0.6, name, size=28, font=SANS, bold=True, color=INK)
    if marked:
        rect(s, cx + 0.42, 2.62, 0.9, 0.045, fill=MARK_DEEP)
    yy = 2.75
    for j, it in enumerate(items):
        if j:
            line(s, cx + 0.4, yy, cx + pw16 - 0.4, yy, HAIR, 1.0)
        text(s, cx + 0.4, yy, pw16 - 0.8, 0.85, it, size=18, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.12)
        yy += 0.85
strip(s, 5.62, 0.9, 'Weaver’s research is the main modern source. She also founded the whiskey brand named after'
      + NB + 'him.', size=19)
footer(s, 16)

# ---------------------------------------------------------------- 17 pour 4
pour_slide(17, 'Pour 4 of 4', ['Jack Daniel’s', 'Bonded'],
           ['Back to Lynchburg, at full strength.',
            'Compare it with the first pour, then try it with a few drops of water.'],
           ['Jack Daniel Distillery,', 'Lynchburg'], ['Tennessee whiskey,', 'bottled in bond'], '100',
           two_line_name=True)

# ---------------------------------------------------------------- 18 reading the label
s = new_slide()
heading(s, 0.85, 'Reading a Tennessee whiskey label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('Tennessee whiskey', 'State law since 2013. Bourbon’s rules, made in Tennessee, maple charcoal before the'
                          + NB + 'barrel.'),
    ('Bourbon', 'Federal law. Tennessee whiskey qualifies, but the label rarely says' + NB + 'so.'),
    ('Sour mash', 'A method. Most Kentucky bourbon is made this way' + NB + 'too.'),
    ('Charcoal filtered', 'On other whiskeys, usually done after the barrel. A different' + NB + 'step.'),
    ('Whisky or whiskey', 'No legal difference.'),
], label_w=3.2, row_h=0.92, label_size=21, size=19)
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
