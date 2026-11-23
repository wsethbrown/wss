"""Glenlivet and the Name Thieves: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/glenlivet-and-the-name-thieves <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there. Layout follows Peat Reek (tools/decks/sources/peat-reek).
Every photograph is credited in research-outline.md, Image credits.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PX, PY, PW = 7.85, 0.75, 4.63   # photo panel on the right of a content slide
PH = 5.5                         # photos are cropped to 4.63 x 5.5
GAP = 0.22


def kicker(s, t, x=X, y=0.8, w=7.0, color=INK):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=color)


def credit(s, x, y, w, t, color=MUTE):
    text(s, x, y, w, 0.5, t, size=9.5, font=SANS, color=color, ls=1.05)


def photo_right(s, name, cap, dark=False):
    picture(s, A / name, PX, PY, PW, PH, radius_in=0.26)
    credit(s, PX, PY + PH + 0.08, PW, cap, color=CREAM_MUTE if dark else MUTE)


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


def pour_slide(n, pour, name, note, maker, style, abv, photo, cap):
    """One pour: a photograph of the distillery (no free photograph of the bottles), the pour line,
    the name, a short note, and Maker / Style / ABV."""
    s = new_slide()
    picture(s, A / photo, X, 0.8, 3.4, 5.3, radius_in=0.26)
    credit(s, X, 6.18, 3.4, cap)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    text(s, x, 1.25, w, 0.85, name, size=44, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 2.4, w, 2.0, note, size=21, italic=True, color=INK, ls=1.2, space_after=6)
    rrect(s, x, 4.6, w, 1.35, r=0.26, fill=WHITE, line=HAIR)
    cols = [('Maker', maker, 2.55), ('Style', style, 3.35), ('ABV', abv, 1.1)]
    cx = x + 0.3
    for label, val, cw in cols:
        text(s, cx, 4.85, cw, 0.3, label, size=12, font=SANS, bold=True, color=MUTE)
        text(s, cx, 5.17, cw, 0.6, val, size=18, color=INK, ls=1.1)
        cx += cw + 0.2
    footer(s, n)
    return s


def year_cards(s, y, items, h, year_size=40, body_size=17):
    n = len(items)
    cw = (CW - (n - 1) * GAP) / n
    for i, (yr, body) in enumerate(items):
        cx = X + i * (cw + GAP)
        rrect(s, cx, y, cw, h, r=0.26, fill=WHITE, line=HAIR)
        text(s, cx + 0.3, y + 0.2, cw - 0.6, 0.75, yr, size=year_size, font=SANS, bold=True, color=INK)
        text(s, cx + 0.3, y + 1.05, cw - 0.5, h - 1.2, body, size=body_size, color=INK, ls=1.2)


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, X, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, X, 2.75, 6.3, 1.6, ['Glenlivet and', 'the Name Thieves'], size=46, font=SANS, bold=True, color=CREAM,
     ls=0.92)
rect(s, X + 0.03, 4.45, 0.9, 0.045, fill=MARK)
text(s, X, 4.65, 6.2, 0.45, 'Speyside, 1824 to now  ·  Four pours', size=17, font=SANS, bold=True, color=CREAM)
text(s, X, 5.2, 5.9, 1.4,
     'In the 1880s the Smiths of The Glenlivet went to law to keep the name to themselves. '
     'Four pours from both sides.', size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw, th = 5.13, 5.83
picture(s, A / 'glenlivet-gable.jpg', 7.35, 0.6, tw, th, radius_in=0.26)
credit(s, 7.35, 0.6 + th + 0.08, tw,
       'The Glenlivet distillery, Minmore, 2004. Photo: Kkonstan, CC BY 3.0, via Wikimedia Commons. Cropped.',
       color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 pour 1
pour_slide(2, 'Pour 1 of 4', 'The Glenlivet 12',
           ['The only distillery allowed to call itself The Glenlivet.',
            'Keep a little back to compare with the other three.'],
           'The Glenlivet, Minmore', 'Speyside single malt, 12 years', '40%',
           'glenlivet-distillery.jpg', 'The Glenlivet distillery, 2009. Photo: Alan Jamieson, CC BY-SA 3.0, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 3 1822
s = new_slide()
heading(s, 0.75, ['In 1822 “Glenlivet” meant', 'smuggled Highland whisky'], size=34, w=6.7, h=1.3)
rrect(s, X, 2.35, 6.55, 2.75, r=0.26, fill=WHITE, line=HAIR)
rect(s, X + 0.35, 2.65, 0.9, 0.045, fill=MARK_DEEP)
text(s, X + 0.35, 2.85, 5.85, 1.5,
     '“Lord Conyngham, the Chamberlain, was looking everywhere for pure Glenlivet whisky; '
     'the King drank nothing else.”', size=20, italic=True, color=INK, ls=1.2)
text(s, X + 0.35, 4.3, 5.85, 0.7,
     ['Elizabeth Grant of Rothiemurchus, on George IV’s visit', 'to Edinburgh. Memoirs of a Highland Lady, 1898.'],
     size=13, font=SANS, color=MUTE, ls=1.1)
text(s, X, 5.4, 6.55, 0.9, ['Her family’s whisky was contraband. George Smith’s', 'distillery did not exist until 1824.'],
     size=18, color=INK, ls=1.2)
photo_right(s, 'glenlivet-glen.jpg',
            'Glenlivet, 2018. Photo: Teddy20152754, CC BY-SA 4.0, via Wikimedia Commons. Cropped.')
footer(s, 3)

# ---------------------------------------------------------------- 4 1824
s = new_slide()
heading(s, 0.75, ['George Smith licensed his', 'still at Drumin in 1824'], size=34, w=6.7, h=1.3)
rows_card(s, X, 2.3, 6.55, [
    ('1823', 'The Excise Act makes legal distilling practical in the Highlands.'),
    ('1824', 'Smith licenses Upper Drumin: the first licence in Glenlivet.'),
    ('1859', 'A new distillery at Minmore, named The Glenlivet.'),
    ('1871', 'George Smith dies. His son John Gordon Smith runs it.'),
], label_w=1.05, row_h=0.98, mark=1, label_size=22, size=16.5)
photo_right(s, 'livet-at-drumin.jpg',
            'The River Livet from Drumin Bridge, 2022. Photo: Gordon Hatton, CC BY-SA 2.0, via geograph.org.uk '
            'and Wikimedia Commons. Cropped.')
footer(s, 4)

# ---------------------------------------------------------------- 5 a style
s = new_slide()
heading(s, 0.85, 'Glenlivet was a style as well as a place', size=40, w=CW, h=0.9)
stats = [('1843', 'Edinburgh', 'Andrew Usher sells Smith’s whisky in London as “The Real Glenlivet”.'),
         ('1862', 'New York', 'Jerry Thomas: Scotch punch “should be Glenlivet or Islay”.'),
         ('1880s', 'The blend', 'Usher’s Old Vatted Glenlivet: about 12% Smith’s whisky, two-thirds grain whisky.')]
g3 = 0.25
c3 = (CW - 2 * g3) / 3
for i, (big, label, body) in enumerate(stats):
    cx = X + i * (c3 + g3)
    rrect(s, cx, 2.05, c3, 4.0, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.35, 2.3, c3 - 0.7, 1.0, big, size=56, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, cx + 0.35, 3.4, c3 - 0.7, 0.5, label, size=22, font=SANS, bold=True, color=MUTE)
    text(s, cx + 0.35, 4.05, c3 - 0.6, 1.9, body, size=18, color=INK, ls=1.2)
footer(s, 5)

# ---------------------------------------------------------------- 6 1868 (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 6.0, 1.8, '1868', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 5.8, 1.2, 'The Smiths warn the trade', size=32, font=SANS, bold=True, color=CREAM, ls=0.95)
text(s, X, 3.7, 5.8, 2.4, [
    'A notice in the Wine Trade Review, signed by George and John Gordon Smith.',
    [('The same notice was still running in the Bombay Gazette in 1885.', {'color': CREAM_MUTE})],
], size=18.5, color=CREAM, ls=1.2, space_after=12)
rrect(s, 7.2, 0.95, 5.28, 5.3, r=0.3, fill=OAK, line=OAK_EDGE)
rect(s, 7.6, 1.4, 0.9, 0.045, fill=MARK)
text(s, 7.6, 1.65, 4.5, 3.6,
     '“Glenlivet is a district which belongs exclusively to his Grace the Duke of Richmond, and their '
     'Distillery was the First and is now the Only Licensed Distillery in Glenlivet.”',
     size=21, italic=True, color=CREAM, ls=1.25)
text(s, 7.6, 5.2, 4.5, 0.8, 'As quoted by ScotchWhisky.com, 2018.', size=13, font=SANS, color=CREAM_MUTE)
footer(s, 6, dark=True)

# ---------------------------------------------------------------- 7 1881
s = new_slide()
heading(s, 0.85, 'In 1881 Smith named two distilleries', size=40, w=CW, h=0.9)
rrect(s, X, 2.05, CW, 2.75, r=0.26, fill=WHITE, line=HAIR)
rect(s, X + 0.4, 2.4, 0.9, 0.045, fill=MARK_DEEP)
text(s, X + 0.4, 2.65, CW - 0.8, 1.9,
     'Dealers were selling “lower priced Whiskies of a different character” bought as '
     '“Glenfarclas Glenlivet or Cragganmore Glenlivet”.', size=26, italic=True, color=INK, ls=1.2)
text(s, X, 5.15, CW, 0.5, 'Smith’s written statement of his intention to go to law, as quoted by ScotchWhisky.com.',
     size=16, italic=True, color=MUTE)
footer(s, 7)

# ---------------------------------------------------------------- 8 pour 2
pour_slide(8, 'Pour 2 of 4', 'Glenfarclas 12',
           ['Named in Smith’s complaint of 1881.', 'About six miles from The Glenlivet.',
            'Owned by the Grant family since 1865.'],
           'Glenfarclas, Ballindalloch', 'Speyside single malt, 12 years', '43%',
           'glenfarclas.jpg',
           'Glenfarclas, 2019. Photo: Anne Burgess, CC BY-SA 2.0, via geograph.org.uk and Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 9 the case
s = new_slide()
heading(s, 0.85, '1882 to 1884: the Glenlivet case', size=40, w=CW, h=0.9)
year_cards(s, 2.05, [
    ('1879', 'The Ushers register Old Vatted Glenlivet as a trade mark.'),
    ('1882', 'Smith asks the High Court to strike other “Glenlivet” names off the register.'),
    ('Reply', 'His rivals: Glenlivet is a district and a style, like Islay.'),
    ('1884', 'Settled out of court. There is no ruling.'),
], h=3.3)
rrect(s, X, 5.6, CW, 0.8, r=0.2, fill=W100)
text(s, X + 0.3, 5.6, CW - 0.6, 0.8, 'Dates of 1880 and 1886, and talk of a court ruling, are not supported.',
     size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 9)

# ---------------------------------------------------------------- 10 the settlement
s = new_slide()
heading(s, 0.85, 'What the 1884 settlement gave each side', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, 'Smith and the Ushers',
          ['Keep the trade mark Glenlivet', 'Only theirs is The Glenlivet', 'Pay £3,000 of the other side’s costs']),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, 'The other distillers',
          ['Glenlivet after their own name', 'May sell “blended Glenlivet”', 'One account lists ten distilleries'])]
for (cx, fill, edge, col, name, lines_) in sides:
    rrect(s, cx, 2.0, pw, 4.45, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.25, pw - 0.8, 0.75, name, size=30, font=SANS, bold=True, color=col)
    yy = 3.15
    for ln in lines_:
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.4, yy + 0.08, pw - 0.8, 0.85, [ln], size=20, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 1.0
rect(s, X + pw + 0.25 + 0.42, 3.0, 0.9, 0.045, fill=MARK)
footer(s, 10)

# ---------------------------------------------------------------- 11 pour 3
pour_slide(11, 'Pour 3 of 4', 'Aberlour 12 Double Cask',
           ['On the list in the 1884 settlement.', 'Built in 1879 and 1880.',
            'Company name until 2007: Aberlour-Glenlivet.'],
           'Aberlour, Aberlour', 'Speyside single malt, 12 years', '40%',
           'aberlour.jpg',
           'Aberlour, 2013. Photo: Peter Moore, CC BY-SA 2.0, via geograph.org.uk and Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 12 1900
s = new_slide()
heading(s, 0.75, ['In 1900 one Greenock firm owned', 'two “-Glenlivet” distilleries'], size=36, w=CW, h=1.3)
pw = (CW - 0.25) / 2
for cx, label, rows in [
        (X, 'R. Thorne & Sons, Greenock', ['Aberlour-Glenlivet Distillery', 'Greenock Distillery',
                                          'Glen Moray-Glenlivet Distillery']),
        (X + pw + 0.25, 'The Glenlivet Distillery', ['“Only Distillery in Glenlivet.”', 'Trade Mark, “GLENLIVET.”'])]:
    rrect(s, cx, 2.3, pw, 3.1, r=0.26, fill=WHITE, line=HAIR)
    text(s, cx + 0.4, 2.5, pw - 0.8, 0.6, label, size=22, font=SANS, bold=True, color=INK)
    yy = 3.2
    for ln in rows:
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR, 1.0)
        text(s, cx + 0.4, yy + 0.05, pw - 0.8, 0.65, ln, size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE)
        yy += 0.7
text(s, X, 5.55, CW, 0.4, 'Advertisements in Slater’s Royal National Commercial Directory of Scotland, 1900.',
     size=14, italic=True, color=MUTE)
rrect(s, X, 6.0, CW, 0.7, r=0.2, fill=W100)
text(s, X + 0.3, 6.0, CW - 0.6, 0.7, 'The trade’s joke: Glenlivet, the longest glen in Scotland.',
     size=19, color=INK, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 12)

# ---------------------------------------------------------------- 13 pour 4
pour_slide(13, 'Pour 4 of 4', 'Glen Moray 12',
           ['Built at Elgin in 1897, after the settlement.', 'It took the suffix anyway.',
            'Still registered: Glen Moray-Glenlivet Distillery Co.'],
           'Glen Moray, Elgin', 'Speyside single malt, 12 years', '40%',
           'glenmoray.jpg',
           'Glen Moray warehouses, 2023. Photo: Richard Sutcliffe, CC BY-SA 2.0, via geograph.org.uk and Wikimedia Commons. '
           'Cropped.')

# ---------------------------------------------------------------- 14 distances
s = new_slide()
heading(s, 0.85, 'Miles from The Glenlivet, in a straight line', size=40, w=CW, h=0.9)
bars = [('The Glenlivet', 0, 'in the glen'), ('Glenfarclas', 5.9, 'about 6'), ('Aberlour', 9.5, 'about 9½'),
        ('Glen Moray', 20.8, 'about 21')]
bx, scale, rh = 4.0, 6.3 / 20.8, 0.95
yy = 2.1
line(s, X, yy, R, yy, HAIR, 1.0)
for name, v, lab in bars:
    text(s, X, yy, 3.0, rh, name, size=22, font=SANS, bold=True, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    if v:
        bw = v * scale
        rect(s, bx, yy + 0.25, bw, rh - 0.5, fill=INK)
    else:
        bw = 0
        dot(s, bx + 0.1, yy + rh / 2, 0.2, MARK_DEEP)
    text(s, bx + bw + 0.3, yy, 1.9, rh, lab, size=20, color=INK, anchor=MSO_ANCHOR.MIDDLE)
    yy += rh
    line(s, X, yy, R, yy, HAIR, 1.0)
text(s, X, 6.15, CW, 0.45, 'Measured between the four distilleries’ map coordinates.',
     size=16, italic=True, color=MUTE)
footer(s, 14)

# ---------------------------------------------------------------- 15 the suffix now
s = new_slide()
heading(s, 0.85, 'Where the suffix is in 2026', size=40, w=CW, h=0.9)
rows_card(s, X, 1.95, CW, [
    ('1980s', '28 distilleries registered as, trading as or labelled “-Glenlivet”.'),
    ('Dropped', 'Macallan; Aberlour’s company, in 2007; most of the rest.'),
    ('Registered', ['Glen Moray-Glenlivet Distillery Co. Ltd.', 'Tomintoul Glenlivet Distillery Limited']),
    ('On labels', 'Cadenhead’s independent bottlings, as of 2022.'),
], label_w=2.4, row_h=1.08, mark=2, label_size=22, size=19)
footer(s, 15)

# ---------------------------------------------------------------- 16 Sláinte
slainte_slide('To George Smith and his son, who fought for the name, and to their neighbours, who kept it.')
