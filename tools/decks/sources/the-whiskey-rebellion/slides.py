"""The Whiskey Rebellion: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/the-whiskey-rebellion <out_root>
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
PY, PH = 0.75, 5.5       # photo frame on the right of a content slide: top and height


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, px_w, px_h, cap, dark=False):
    """A photo crop at a fixed height, its own width, right-aligned, with its credit under it.
    Returns the photo's left edge."""
    w = PH * px_w / px_h
    x = R - w
    picture(s, A / name, x, PY, w, PH, radius_in=0.26)
    credit(s, x, PY + PH + 0.08, w, cap, color=CREAM_MUTE if dark else MUTE)
    return x


def rows_card(s, x, y, w, items, label_w, row_h, mark=None, label_size=20, size=17.5, pad=0.3):
    """A white hairline card of label / text rows. mark: index of the row to mark with an orange dot.
    row_h: one height for every row, or a list of heights, one per row."""
    hs = row_h if isinstance(row_h, (list, tuple)) else [row_h] * len(items)
    rrect(s, x, y, w, sum(hs) + 0.1, r=0.26, fill=WHITE, line=HAIR)
    yy = y + 0.05
    for i, ((label, val), row_h) in enumerate(zip(items, hs)):
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


def pour_slide(n, pour, name, note, maker, style, proof, two_line_name=True,
               widths=(2.85, 3.35, 0.6), val_size=18):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / Proof
    (the old card's labels)."""
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


def two_cards(s, y, h, left, right, row_hs, note_y):
    """White card and raised green card side by side: a name, rows with hairlines, a closing note.
    left / right: (name, rows, note); a row is a str, a list of runs (tuples) or a list of paragraphs."""
    pw = (CW - 0.25) / 2
    sides = [(X, WHITE, HAIR, INK, MUTE, left), (X + pw + 0.25, OAK, OAK_EDGE, CREAM, CREAM_MUTE, right)]
    for (cx, fill, edge, col, quiet, (name, rows, note)) in sides:
        rrect(s, cx, y, pw, h, r=0.3, fill=fill, line=edge)
        text(s, cx + 0.4, y + 0.25, pw - 0.8, 0.75, name, size=34, font=SANS, bold=True, color=col)
        yy = y + 1.1
        for row, rh in zip(rows, row_hs):
            line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
            paras = row if isinstance(row, list) and not isinstance(row[0], tuple) else [row]
            text(s, cx + 0.4, yy + 0.04, pw - 0.8, rh, paras, size=20, color=col, anchor=MSO_ANCHOR.MIDDLE,
                 ls=1.12)
            yy += rh
        text(s, cx + 0.4, note_y, pw - 0.8, 0.9, note, size=16.5, color=quiet, ls=1.15)
    rect(s, X + pw + 0.25 + 0.42, y + 1.0, 0.9, 0.045, fill=MARK)


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.65, 2.0, 2.0 * LOGO_RATIO)
text(s, X, 2.45, 6.5, 1.75, ['The Whiskey', 'Rebellion'], size=56, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.3, 0.9, 0.045, fill=MARK)
text(s, X, 4.5, 6.2, 0.45, 'Western Pennsylvania, 1791–1794  ·  Four pours', size=17, font=SANS, bold=True,
     color=CREAM)
text(s, X, 5.05, 6.2, 1.5,
     ['In 1791 Congress taxed whiskey.', 'In 1794 Washington sent an army into', 'western Pennsylvania to enforce the tax.'],
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 4.95
th = tw * 1234 / 1104
picture(s, A / 'washington-fort-cumberland-kemmelmeyer.jpg', 7.53, 0.55, tw, th, radius_in=0.26)
credit(s, 7.53, 0.55 + th + 0.08, tw,
       'Washington reviewing the army at Fort Cumberland, Maryland, in 1794. Attributed to Frederick '
       'Kemmelmeyer. Metropolitan Museum of Art, public domain.', color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 the war debts
s = new_slide()
px = photo_right(s, 'hamilton-trumbull-1806.jpg', 960, 1254,
                 'Alexander Hamilton, Secretary of the Treasury, painted by John Trumbull in 1806. Public domain.')
lw = px - 0.35 - X
heading(s, 0.75, ['In 1790 the federal', 'government took on the', 'war debts.'], size=36, w=lw, h=1.8)
rows_card(s, X, 2.55, lw, [
    ('Congress', ['assumes the states’', 'Revolutionary War debts']),
    ('Hamilton', ['needs a steady income', 'to pay the interest']),
    ('Imports', 'already taxed at the ports'),
    ('Spirits', 'made at home, taxed from 1791'),
], label_w=1.75, row_h=0.9, mark=3, label_size=22, size=19)
footer(s, 2)

# ---------------------------------------------------------------- 3 eastern distillers, western farmers
# The old slide had two column titles and no heading; it shows the script's.
s = new_slide()
heading(s, 0.75, 'Eastern distillers and western farmers', size=40, w=CW, h=0.9)
two_cards(s, 1.9, 4.6,
          ('Eastern distillers',
           ['A large still in or near a town', 'Runs most of the year',
            ['Pays by the gallon, from', [('sales made for ', {}), ('cash', {'bold': True})]]],
           'Excise Act, 3 March 1791: 9 to 25 cents a gallon, by strength.'),
          ('Western farmers',
           ['A small still on the farm', 'Runs a few weeks after harvest',
            [('Owes the tax in ', {}), ('coin', {'bold': True}), (', which was scarce west of the mountains', {})]],
           'Country stills could pay 60 cents a year per gallon of still capacity instead.'),
          row_hs=(0.66, 0.66, 1.0), note_y=5.5)
footer(s, 3)

# ---------------------------------------------------------------- 4 whiskey was how grain got to market
s = new_slide()
px = photo_right(s, 'farm-still-scribners.jpg', 1056, 1234,
                 'Men at a farm still, with sacks of rye. Engraving from Scribner’s Popular History of the '
                 'United States. Public domain.')
lw = px - 0.4 - X
heading(s, 0.75, ['West of the Alleghenies,', 'whiskey was how grain', 'got to market.'], size=36, w=lw, h=1.8)
text(s, X, 2.75, lw, 2.2,
     'A packhorse could carry far more value as whiskey than as rye, and the whiskey did not spoil. '
     'Farmers also paid debts and wages with it.', size=20, color=INK, ls=1.25)
text(s, X, 4.2, lw, 1.0, 'Spain kept the Mississippi closed to American trade until a treaty in 1795.',
     size=18, color=MUTE, ls=1.2)
footer(s, 4)

# ---------------------------------------------------------------- 5 pour 1
pour_slide(5, 'Pour 1 of 4', ['Old Overholt', 'Straight Rye'],
           'The brand began in Westmoreland County in 1810. Westmoreland was one of the four counties '
           'of the rebellion.',
           'Jim Beam, Kentucky', 'Straight rye whiskey', '86')

# ---------------------------------------------------------------- 6 collectors attacked
s = new_slide()
heading(s, 0.75, 'Collectors were attacked from 1791', size=40, w=CW, h=0.9)
rows_card(s, X, 1.75, CW, [
    ('Sept 1791', 'Robert Johnson, collector for two western counties, is tarred and feathered.'),
    ('Aug 1792', 'A meeting in Pittsburgh calls the tax unjust and tells people to shun collectors.'),
    ('1794', '“Tom the Tinker” shoots holes in the stills of farmers who registered.'),
], label_w=1.7, row_h=0.66, label_size=22, size=18.5)
ew = CW
eh = ew * 376 / 2058
picture(s, A / 'an-exciseman-1792.jpg', X, 4.15, ew, eh, radius_in=0.2)
credit(s, X, 4.15 + eh + 0.08, ew,
       '“An Exciseman”, an anonymous hand-drawn satire. Its verse is dated 13 August 1792. Atwater Kent '
       'Museum, Philadelphia. Public domain.')
footer(s, 6)

# ---------------------------------------------------------------- 7 summonses to Philadelphia
s = new_slide()
heading(s, 0.85, 'July 1794: summonses to a court in Philadelphia', size=34, w=CW, h=0.9)
gap = 1.9
bw = (CW - gap) / 2
by, bh = 1.95, 1.75
rrect(s, X, by, bw, bh, r=0.26, fill=WHITE, line=HAIR)
text(s, X + 0.35, by + 0.25, bw - 0.7, 0.5, 'Western Pennsylvania', size=22, font=SANS, bold=True, color=INK)
text(s, X + 0.35, by + 0.8, bw - 0.7, 0.9, 'More than 60 distillers who had not registered their stills',
     size=18, color=INK, ls=1.15)
fx = X + bw + gap
rrect(s, fx, by, bw, bh, r=0.26, fill=OAK, line=OAK_EDGE)
rect(s, fx + 0.35, by + 0.22, 0.9, 0.045, fill=MARK)
text(s, fx + 0.35, by + 0.32, bw - 0.6, 0.5, 'Federal court, Philadelphia', size=22, font=SANS, bold=True,
     color=CREAM)
text(s, fx + 0.35, by + 0.87, bw - 0.7, 0.8, 'Where the writs told them to appear', size=18, color=CREAM, ls=1.15)
line(s, X + bw + 0.2, by + bh / 2 - 0.05, fx - 0.2, by + bh / 2 - 0.05, MUTE, 1.5)
text(s, X + bw, by + bh / 2 + 0.05, gap, 0.4, 'about 300 miles', size=15, font=SANS, bold=True, color=INK,
     align=PP_ALIGN.CENTER)
pw = (CW - 0.3) / 2
for i, (name, body) in enumerate([
        ('John Neville', 'Inspector of the excise for the region. A wealthy Revolutionary War officer living at '
                         'Bower Hill.'),
        ('David Lenox', 'U.S. marshal, riding with Neville to serve the writs.')]):
    cx = X + i * (pw + 0.3)
    rrect(s, cx, 4.1, pw, 2.0, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.35, 4.3, pw - 0.7, 0.5, name, size=24, font=SANS, bold=True, color=INK)
    text(s, cx + 0.35, 4.9, pw - 0.7, 1.1, body, size=18, color=INK, ls=1.15)
footer(s, 7)

# ---------------------------------------------------------------- 8 17 July 1794 (the green story slide)
s = new_slide(INK)
text(s, X, 0.8, CW, 0.5, 'Bower Hill is burned', size=26, font=SANS, bold=True, color=CREAM)
text(s, 0.75, 1.35, CW, 1.9, '17 July 1794', size=120, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 3.3, 1.2, 0.045, fill=MARK)
text(s, X, 3.6, 10.6, 1.6,
     'About 500 armed men surrounded John Neville’s house, a day after shots from the house had killed a '
     'farmer, Oliver Miller. A few soldiers from the Pittsburgh garrison held it.',
     size=22, color=CREAM, ls=1.25)
text(s, X, 5.3, 10.6, 1.0,
     'The rebels’ leader, James McFarlane, was shot dead during a pause in the firing. The house was burned.',
     size=19, color=CREAM_MUTE, ls=1.2)
footer(s, 8, dark=True)

# ---------------------------------------------------------------- 9 Braddock's Field
s = new_slide()
heading(s, 0.85, 'Braddock’s Field, 1 August 1794', size=40, w=CW, h=0.9)
text(s, 0.75, 1.85, 5.2, 1.6, '7,000', size=110, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 3.5, 1.2, 0.045, fill=MARK_DEEP)
text(s, X, 3.75, 4.9, 1.6,
     'armed men by the usual estimate (some accounts say 5,000 or 6,000) mustered outside Pittsburgh',
     size=19, color=MUTE, ls=1.2)
cx = 6.2
rrect(s, cx, 1.95, R - cx, 1.2 * 3 + 0.1, r=0.26, fill=WHITE, line=HAIR)
for i, t in enumerate(['Some talked of attacking the fort at Pittsburgh and of a separate western state.',
                       'The town sent out food and whiskey. The crowd marched through Pittsburgh and went home.',
                       'Bradford’s men had robbed the mail to find out who opposed them.']):
    yy = 2.0 + i * 1.2
    if i:
        line(s, cx + 0.3, yy, R - 0.3, yy, HAIR, 1.0)
    if i == 2:
        dot(s, cx + 0.16, yy + 0.6, 0.12, MARK_DEEP)
    text(s, cx + 0.35, yy, R - cx - 0.65, 1.2, t, size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.15)
footer(s, 9)

# ---------------------------------------------------------------- 10 pour 2
pour_slide(10, 'Pour 2 of 4', ['Pikesville', 'Straight Rye'],
           ['Pikesville was a Maryland rye. Maryland was one of the four states that sent militia west in 1794.',
            'It is 110 proof.'],
           'Heaven Hill, Kentucky', 'Straight rye whiskey', '110')

# ---------------------------------------------------------------- 11 13,000 (big number, on paper)
s = new_slide()
text(s, 0.75, 1.15, 6.2, 1.9, '13,000', size=130, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 3.15, 1.2, 0.045, fill=MARK_DEEP)
text(s, 6.95, 1.35, R - 6.95, 1.9, ['Washington sends', 'the militia west in', 'autumn 1794'],
     size=34, font=SANS, bold=True, color=INK, ls=0.95)
text(s, X, 3.75, 10.8, 1.6,
     'Men from New Jersey, Pennsylvania, Maryland and Virginia. Washington rode with them as far as Bedford, '
     'then handed command to Henry Lee.', size=23, color=INK, ls=1.25)
footer(s, 11)

# ---------------------------------------------------------------- 12 no battle
s = new_slide()
heading(s, 0.85, 'The rebellion ended without a battle', size=40, w=CW, h=0.9)
rows_card(s, X, 1.95, CW, [
    ('Nov 1794', 'The army finds no one to fight. Men are pulled from their beds and held for questioning.'),
    ('Bradford', 'David Bradford, the best-known rebel leader, escapes down the Ohio.'),
    ('1795', 'About 20 prisoners are taken to Philadelphia. Two are convicted of treason and sentenced to hang.'),
    ('Pardoned', 'In November 1795 Washington pardons both, Philip Wigle and John Mitchell.'),
], label_w=2.2, row_h=1.0, mark=3, label_size=26, size=20)
footer(s, 12)

# ---------------------------------------------------------------- 13 1802 repeal
s = new_slide()
px = photo_right(s, 'jefferson-peale-1800.jpg', 864, 1254,
                 'Thomas Jefferson, painted by Rembrandt Peale in 1800. Public domain.')
lw = px - 0.35 - X
heading(s, 0.75, ['1802: Jefferson’s Congress', 'repeals the excise'], size=36, w=lw, h=1.3)
rows_card(s, X, 2.25, lw, [
    ('1795–1801', 'The excise stays in force.'),
    ('1801', 'Jefferson takes office. His party had opposed the excise.'),
    ('1802', 'Internal taxes repealed on 6 April 1802, whiskey included.'),
    ('1862', 'A federal whiskey tax returns, to pay for the Civil War, and stays.'),
], label_w=2.0, row_h=0.95, mark=2, label_size=24, size=19)
footer(s, 13)

# ---------------------------------------------------------------- 14 pour 3
pour_slide(14, 'Pour 3 of 4', ['Michter’s US*1', 'Straight Rye'],
           ['The name comes from an old distillery in Lebanon County, Pennsylvania.',
            'The company now distills in Louisville.'],
           'Michter’s, Kentucky', 'Single barrel straight rye', '84.8')

# ---------------------------------------------------------------- 15 the legend
s = new_slide()
heading(s, 0.85, 'The rebels and bourbon: a legend', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
for i, (name, body) in enumerate([
        ('The story', 'Rebels fled the army to Kentucky, out of the tax man’s reach, and started making bourbon there.'),
        ('The record', 'Kentucky was distilling in the 1780s and resisted the tax too. The earliest known printed '
                       '“bourbon whiskey” is an advertisement of 1821.')]):
    cx = X + i * (pw + 0.25)
    dark = i == 1
    rrect(s, cx, 1.95, pw, 3.05, r=0.3, fill=OAK if dark else WHITE, line=OAK_EDGE if dark else HAIR)
    if dark:
        rect(s, cx + 0.42, 2.25, 0.9, 0.045, fill=MARK)
    text(s, cx + 0.4, 2.4, pw - 0.8, 0.6, name, size=30, font=SANS, bold=True, color=CREAM if dark else INK)
    text(s, cx + 0.4, 3.15, pw - 0.8, 2.0, body, size=20, color=CREAM if dark else INK, ls=1.2)
strip(s, 5.35, 0.8, 'Virginia created Bourbon County in the mid-1780s, before Kentucky became a state in 1792.',
      size=19)
footer(s, 15)

# ---------------------------------------------------------------- 16 pour 4
pour_slide(16, 'Pour 4 of 4', ['Elijah Craig', 'Small Batch'],
           ['Named for a Baptist preacher in Kentucky.',
            'People later said he made the first bourbon. There is no proof of that.'],
           'Heaven Hill, Kentucky', 'Kentucky straight bourbon', '94')

# ---------------------------------------------------------------- 17 reading the label
s = new_slide()
heading(s, 0.75, 'Reading a rye whiskey label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.75, CW, [
    ('Rye whiskey', 'Defined by law. At least 51% rye in the mash, aged in new charred oak.'),
    ('Straight', 'Defined by law. At least two years old, nothing added.'),
    ('Bottled in bond', 'Defined by law. One distiller, one season, at least four years, 100 proof.'),
    (['Pennsylvania style,', 'Maryland style,', 'Monongahela'], 'No legal definition. Old regional names.'),
], label_w=3.4, row_h=(1.0, 0.85, 1.0, 1.4), label_size=21, size=20)
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
