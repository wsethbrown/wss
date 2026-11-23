"""Lagavulin vs Laphroaig: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/lagavulin-vs-laphroaig <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there. Layout follows Peat Reek (tools/decks/sources/peat-reek).
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


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


def pour_slide(n, pour, name, note, maker, style, abv):
    """One pour: a bottle-shaped placeholder card, the pour line, the name, a short note,
    and Maker / Style / ABV, as in Peat Reek."""
    s = new_slide()
    bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    text(s, x, 1.25, w, 0.85, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 2.4, w, 1.9, note, size=21, italic=True, color=INK, ls=1.2)
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
text(s, X, 2.95, 6.3, 1.7, ['Lagavulin', 'vs Laphroaig'], size=54, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.72, 0.9, 0.045, fill=MARK)
text(s, X, 4.92, 6.2, 0.45, 'Two Islay distilleries  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 5.48, 5.9, 1.3,
     'One firm sold both whiskies for about sixty years. In 1908 Lagavulin’s owner tried to make Laphroaig himself.',
     size=19, italic=True, color=CREAM_MUTE, ls=1.2)
tw, th = 5.13, 4.1
ty = 1.35
picture(s, A / 'lagavulin-barnard-1887.jpg', 7.35, ty, tw, th, radius_in=0.26)
credit(s, 7.35, ty + th + 0.08, tw,
       'Lagavulin distillery, Islay. Engraving from Alfred Barnard’s survey of distilleries, 1887. '
       'Public domain; cropped.', color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 Mackie
s = new_slide()
heading(s, 0.75, 'Peter Mackie, 1855 to 1924', size=40, w=7.9, h=0.9)
text(s, X, 1.65, 7.2, 0.5, 'Owner of Lagavulin, maker of White Horse.',
     size=19, italic=True, color=MUTE)
rows_card(s, X, 2.45, 7.3, [
    ('1855', 'Born near Stirling.'),
    ('1878', 'Joins his uncle’s Glasgow whisky firm and learns distilling at Lagavulin.'),
    ('1889', 'Takes over the firm when his uncle dies.'),
    ('1890', 'Registers White Horse. Invests in a new Speyside distillery.'),
], label_w=1.1, row_h=0.92, mark=3, label_size=22, size=17.5)
MW, MH = 3.55, 5.45
MX = R - MW
picture(s, A / 'mackie-vanity-fair-1908.jpg', MX, 0.75, MW, MH, radius_in=0.26)
credit(s, MX, 0.75 + MH + 0.08, MW,
       'Mackie as “Restless Peter”, by Spy (Leslie Ward), Vanity Fair, 8 April 1908. Public domain; trimmed.')
footer(s, 2)

# ---------------------------------------------------------------- 3 pour 1
pour_slide(3, 'Glass 1 of 4', 'Craigellachie 13',
           ['From the Speyside distillery Mackie invested in, built in 1890 and 1891.',
            'No peat.'],
           'Craigellachie, Speyside', 'Speyside single malt, 13 years', '46%')

# ---------------------------------------------------------------- 4 two distilleries
s = new_slide()
heading(s, 0.85, 'Two distilleries two miles apart', size=40, w=CW, h=0.9)
text(s, X, 1.75, CW, 0.5, 'As Alfred Barnard found them in the mid-1880s, in his survey published in 1887.',
     size=20, italic=True, color=MUTE)
pw = (CW - 0.25) / 2
sides = [('Lagavulin', [('Output', '75,000 gallons a year'), ('Stills', 'Two'),
                        ('Water', 'Two lochs on the hill'), ('Sold', 'Single whisky and blends')]),
         ('Laphroaig', [('Output', '23,000 gallons a year'), ('Stills', 'Two old pot stills'),
                        ('Water', 'A burn through the property'), ('Sold', 'All by Mackie & Co, Glasgow')])]
for i, (name, rows) in enumerate(sides):
    cx = X + i * (pw + 0.25)
    rrect(s, cx, 2.5, pw, 3.95, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.35, 2.68, pw - 0.7, 0.6, name, size=28, font=SANS, bold=True, color=INK)
    yy = 3.4
    for j, (lab, val) in enumerate(rows):
        line(s, cx + 0.35, yy, cx + pw - 0.35, yy, HAIR, 1.0)
        if i == 1 and j == 3:
            dot(s, cx + 0.18, yy + 0.375, 0.12, MARK_DEEP)
        text(s, cx + 0.35, yy, 1.3, 0.75, lab, size=15, font=SANS, bold=True, color=MUTE, anchor=MSO_ANCHOR.MIDDLE)
        text(s, cx + 1.7, yy, pw - 2.05, 0.75, val, size=18, color=INK, anchor=MSO_ANCHOR.MIDDLE, ls=1.1)
        yy += 0.75
footer(s, 4)

# ---------------------------------------------------------------- 5 one firm sold both
s = new_slide()
heading(s, 0.85, 'For sixty years one firm sold both', size=40, w=CW, h=0.9)
gap = 0.22
cw = (CW - 3 * gap) / 4
events = [('1815–16', 'Laphroaig and Lagavulin are licensed.'),
          ('1847', 'Laphroaig’s owner dies. Lagavulin’s Graham runs it for his son.'),
          ('1857', 'The son takes over. The Lagavulin firm stays on as Laphroaig’s agent.'),
          ('1907', 'Laphroaig’s new owners end the agency.')]
for i, (yr, body) in enumerate(events):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.05, cw, 3.25, r=0.26, fill=WHITE, line=HAIR)
    if i == 3:
        rect(s, cx + 0.3, 2.3, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.45, cw - 0.5, 0.75, yr, size=36, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.3, cw - 0.5, 1.9, body, size=17, color=INK, ls=1.2)
rrect(s, X, 5.6, CW, 0.8, r=0.2, fill=W100)
text(s, X + 0.3, 5.6, CW - 0.6, 0.8, 'By the 1880s that firm was Mackie & Co of Glasgow.',
     size=20, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 5)

# ---------------------------------------------------------------- 6 White Horse
s = new_slide()
heading(s, 0.85, 'White Horse, registered in 1890', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('The name', 'An old coaching inn on Edinburgh’s Canongate.'),
    ('1901', 'Launched in Britain after selling abroad first.'),
    ('1902–14', 'Mackie spends £90,000 advertising it. Home sales go from 700 to 70,000 cases a year.'),
    ('The malt', 'Built on Lagavulin, with Craigellachie.'),
], label_w=2.0, row_h=1.05, mark=3, label_size=22, size=19)
footer(s, 6)

# ---------------------------------------------------------------- 7 pour 2
pour_slide(7, 'Glass 2 of 4', 'White Horse',
           ['Mackie’s blend, built on Lagavulin.'],
           'Diageo', 'Blended Scotch whisky', '40%')

# ---------------------------------------------------------------- 8 1907
s = new_slide()
heading(s, 0.85, '1907: Laphroaig ends Mackie’s agency', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('The heirs', 'Laphroaig’s owner dies. His sisters and nephew inherit it.'),
    ('The court', 'They take Mackie to court and end his agency.'),
    ('The water', 'Laphroaig says Mackie cut off its water and a court made him restore it.'),
], label_w=2.0, row_h=1.15, mark=2, label_size=22, size=19)
footer(s, 8)

# ---------------------------------------------------------------- 9 pour 3
pour_slide(9, 'Glass 3 of 4', 'Lagavulin 16',
           ['Mackie’s own distillery.'],
           'Lagavulin, Islay', 'Islay single malt, 16 years', '43%')

# ---------------------------------------------------------------- 10 Malt Mill
s = new_slide()
heading(s, 0.85, '1908: Malt Mill, inside Lagavulin', size=40, w=CW, h=0.9)
cols = [('The aim', 'Make Laphroaig at Lagavulin.'),
        ('The copy', 'The story is that he copied Laphroaig’s stills and hired its brewer.'),
        ('The result', 'Nothing like Laphroaig. It went into Mackie’s blends.'),
        ('The end', 'Stopped around 1960. Its stills went into Lagavulin.')]
for i, (t, body) in enumerate(cols):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.05, cw, 3.55, r=0.26, fill=WHITE, line=HAIR)
    if i == 2:
        rect(s, cx + 0.3, 2.3, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.3, 2.5, cw - 0.6, 0.6, t, size=26, font=SANS, bold=True, color=INK)
    text(s, cx + 0.3, 3.25, cw - 0.5, 2.2, body, size=18, color=INK, ls=1.2)
text(s, X, 5.9, CW, 0.5, 'No bottle of Malt Mill has been proved genuine.', size=18, italic=True, color=MUTE)
footer(s, 10)

# ---------------------------------------------------------------- 11 Barnard (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 6.4, 1.8, '1887', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 11.0, 1.2, 'Barnard: two distilleries a short distance apart, two different whiskies.',
     size=32, font=SANS, bold=True, color=CREAM, ls=0.95)
text(s, X, 4.15, 10.6, 2.2, [
    'He gives Lagavulin and Laphroaig as his example of how locality, water and position fix a whisky’s character.',
    [('His book came out in 1887. Mackie built Malt Mill in 1908.', {'color': CREAM_MUTE})],
], size=20, color=CREAM, ls=1.2, space_after=12)
footer(s, 11, dark=True)

# ---------------------------------------------------------------- 12 Laphroaig after Mackie
s = new_slide()
heading(s, 0.85, 'Laphroaig sells its own whisky', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, 5.75, [
    ('1908', 'Ian Hunter, the nephew, arrives.'),
    ('1921', 'Laphroaig buys its land.'),
    ('1923–24', 'Two stills become four.'),
    ('c. 1927', 'Sold direct, with no agent.'),
    ('1954', 'Bessie Williamson takes charge.'),
], label_w=1.35, row_h=0.88, mark=3, label_size=19, size=17)
LW, LH = 5.5, 5.5 * 1065 / 1600
LX = R - LW
picture(s, A / 'laphroaig-2011.jpg', LX, 2.0, LW, LH, radius_in=0.26)
credit(s, LX, 2.0 + LH + 0.08, LW,
       'Laphroaig distillery, 2011. Photo: John Allan, CC BY-SA 2.0, via Wikimedia Commons; cropped.')
footer(s, 12)

# ---------------------------------------------------------------- 13 pour 4
pour_slide(13, 'Glass 4 of 4', 'Laphroaig 10',
           ['The whisky Mackie sold for years and then tried to copy.',
            'Same strength as the Lagavulin. Made two miles away.'],
           'Laphroaig, Islay', 'Islay single malt, 10 years', '43%')

# ---------------------------------------------------------------- 14 today
s = new_slide()
heading(s, 0.85, 'The two distilleries today', size=40, w=CW, h=0.9)
sides = [(X, WHITE, HAIR, INK, 'Lagavulin',
          ['Four stills', 'Floor maltings closed in 1974', 'Water from the lochs on the hill', 'Owned by Diageo']),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'Laphroaig',
          ['Seven stills', 'Still malts about a fifth of its barley', 'Water from the Kilbride stream',
           'Owned by Suntory since 2014'])]
for (cx, fill, edge, col, name, lines_) in sides:
    rrect(s, cx, 2.0, pw, 4.45, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.25, pw - 0.8, 0.75, name, size=34, font=SANS, bold=True, color=col)
    yy = 3.1
    for ln in lines_:
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.4, yy + 0.05, pw - 0.8, 0.7, ln, size=20, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 0.78
rect(s, X + pw + 0.25 + 0.42, 3.0, 0.9, 0.045, fill=MARK)
footer(s, 14)

# ---------------------------------------------------------------- 15 Sláinte
slainte_slide('To Lagavulin and to Laphroaig.')
