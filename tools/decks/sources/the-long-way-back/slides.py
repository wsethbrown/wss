"""The Long Way Back: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/the-long-way-back <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.

A remake of the deck the older picture-per-slide builder made: the same slides, words and
photographs, laid out with the house kit (Peat Reek and Rye Country are the models). The
photographs are cropped from that deck's slide images (no other copy was kept); their credits
are the old captions, word for word.
"""
from wsskit import *

X = 0.85                 # left margin
R = 12.48                # right edge of the content area
CW = R - X               # content width
PX, PY, PW = 7.85, 0.75, 4.63   # photo panel on the right of a content slide


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


def pour_slide(n, pour, name, note, maker, style, abv, two_line_name=False,
               widths=(2.6, 3.3, 0.75), val_size=18):
    """One pour: a bottle-shaped placeholder card (no free photograph of any of the four bottles
    was in the old deck), the pour line, the name, the old slide's note, and Maker / Style / ABV."""
    s = new_slide()
    bottle_placeholder(s, X, 0.8, 3.4, 5.3)
    x, w = 4.85, 7.63
    kicker(s, pour, x=x)
    name_h = 1.55 if two_line_name else 0.85
    text(s, x, 1.25, w, name_h, name, size=46, font=SANS, bold=True, color=INK, ls=0.92)
    text(s, x, 1.25 + name_h + 0.3, w, 1.4, note, size=21, italic=True, color=INK, ls=1.2)
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
text(s, X, 2.45, 6.5, 1.75, ['The Long', 'Way Back'], size=56, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 4.3, 0.9, 0.045, fill=MARK)
text(s, X, 4.5, 6.2, 0.45, 'Irish whiskey, 1880 to now  ·  Four pours', size=17, font=SANS, bold=True,
     color=CREAM)
text(s, X, 5.05, 6.0, 1.5,
     ['How the biggest whiskey trade of the', 'nineteenth century fell to two distilleries,',
      'and how it came back.'],
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
tw = 4.95
th = tw * 1220 / 1104
picture(s, A / 'lockes-kilbeggan-french.jpg', 7.53, 0.55, tw, th, radius_in=0.26)
credit(s, 7.53, 0.55 + th + 0.08, tw,
       'Locke’s distillery, Kilbeggan, between 1880 and 1900. Robert French, Lawrence Collection, '
       'National Library of Ireland. No known restrictions.', color=CREAM_MUTE)

# ---------------------------------------------------------------- 2 Dublin's four
s = new_slide()
heading(s, 0.75, ['Dublin’s four big', 'distillers in the 1880s'], size=36, w=6.7, h=1.3)
rows_card(s, X, 2.2, 6.7, [
    ('John Jameson', 'Bow Street'),
    ('William Jameson', 'Marrowbone Lane'),
    ('John Power', 'John’s Lane'),
    ('George Roe', 'Thomas Street'),
], label_w=2.55, row_h=0.72, label_size=19, size=19)
text(s, X, 5.3, 6.7, 1.2, 'All four made whiskey in copper pot stills and sold it across Britain and the Empire.',
     size=19, color=INK, ls=1.2)
photo_right(s, 'bow-street-barnard-1887.jpg',
            'Bow Street distillery, Dublin, engraved for Alfred Barnard’s survey of 1887. Public domain.',
            1255 / 1056)
footer(s, 2)

# ---------------------------------------------------------------- 3 single pot still
s = new_slide()
heading(s, 0.85, 'Single pot still: malted and unmalted barley', size=38, w=CW, h=0.9)
gap = 0.55
cw = (CW - 2 * gap) / 3
cards = [('Malted barley', 'Taxed as malt'),
         ('Unmalted barley', 'Not taxed as malt'),
         ('Copper pot stills', 'Usually three distillations')]
for i, (name, body) in enumerate(cards):
    cx = X + i * (cw + gap)
    rrect(s, cx, 2.1, cw, 2.2, r=0.26, fill=WHITE, line=HAIR)
    if i == 1:
        rect(s, cx + 0.35, 2.35, 0.9, 0.045, fill=MARK_DEEP)
    text(s, cx + 0.35, 2.5, cw - 0.6, 0.6, name, size=26, font=SANS, bold=True, color=INK)
    text(s, cx + 0.35, 3.2, cw - 0.6, 1.0, body, size=20, color=INK, ls=1.2)
    if i < 2:
        text(s, cx + cw, 2.1, gap, 2.2, '+' if i == 0 else '→', size=30, font=SANS, bold=True, color=MUTE,
             align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
strip(s, 4.75, 1.2, ['The usual explanation for the unmalted grain is a tax on malt.',
                    'Historians argue over how much the tax mattered.'], size=21)
footer(s, 3)

# ---------------------------------------------------------------- 4 pour 1
pour_slide(4, 'Pour 1 of 4', ['Redbreast', '12 Year Old'],
           ['Notice the texture before the flavour.', 'Unmalted barley is usually credited with a thick, oily feel.'],
           ['Irish Distillers,', 'Midleton'], ['Single pot still', 'Irish whiskey'], '40%', two_line_name=True)

# ---------------------------------------------------------------- 5 pot still and Coffey still
# The old slide had two column titles and no heading; it shows the script's.
s = new_slide()
heading(s, 0.85, 'Pot still and Coffey still', size=40, w=CW, h=0.9)
pw = (CW - 0.25) / 2
sides = [(X, WHITE, HAIR, INK, MUTE, 'Pot still',
          ['One batch at a time', 'Run two or three times', 'Heavy, oily spirit'],
          'What the Dublin houses used and kept using.'),
         (X + pw + 0.25, OAK, OAK_EDGE, CREAM, CREAM_MUTE, 'Coffey still, 1830',
          ['Runs without stopping', 'Any grain, cheaply', 'Light, high-strength spirit'],
          'Patented by Aeneas Coffey, once head of the Irish excise. Scottish grain distillers bought it.')]
for (cx, fill, edge, col, quiet, name, lines_, note) in sides:
    rrect(s, cx, 2.0, pw, 4.35, r=0.3, fill=fill, line=edge)
    text(s, cx + 0.4, 2.25, pw - 0.8, 0.75, name, size=34, font=SANS, bold=True, color=col)
    yy = 3.1
    for ln in lines_:
        line(s, cx + 0.4, yy, cx + pw - 0.4, yy, HAIR if fill == WHITE else OAK_EDGE, 1.0)
        text(s, cx + 0.4, yy + 0.08, pw - 0.8, 0.6, ln, size=21, color=col, anchor=MSO_ANCHOR.MIDDLE)
        yy += 0.72
    text(s, cx + 0.4, yy + 0.15, pw - 0.8, 0.9, note, size=17, color=quiet, ls=1.15)
rect(s, X + pw + 0.25 + 0.42, 3.0, 0.9, 0.045, fill=MARK)
footer(s, 5)

# ---------------------------------------------------------------- 6 1909 (the green story slide)
s = new_slide(INK)
text(s, 0.75, 0.6, 6.6, 1.8, '1909', size=130, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, X + 0.03, 2.5, 1.2, 0.045, fill=MARK)
text(s, X, 2.75, 6.7, 1.6, ['A Royal Commission declines', 'to limit whisky to the pot still.'],
     size=28, font=SANS, bold=True, color=CREAM, ls=0.98)
text(s, X, 4.0, 6.6, 2.0,
     'Dublin’s distillers had argued for thirty years that it was not. The ruling cleared the way for '
     'blended Scotch.', size=19, color=CREAM_MUTE, ls=1.25)
photo_right(s, 'johns-lane-barnard-1887.jpg',
            'Powers’ John’s Lane distillery, Dublin, engraved for Alfred Barnard, 1887. Public domain.',
            1163 / 1056, dark=True)
footer(s, 6, dark=True)

# ---------------------------------------------------------------- 7 two jurisdictions
s = new_slide()
heading(s, 0.75, ['From 1922,', 'two jurisdictions'], size=36, w=6.7, h=1.3)
rows_card(s, X, 2.2, 6.7, [
    (['Irish Free', 'State'], 'Dublin, Cork, Tullamore, Kilbeggan. Behind British tariffs from 1932 to 1938.'),
    (['Northern', 'Ireland'], 'Bushmills and Belfast. Still inside the United Kingdom.'),
], label_w=1.85, row_h=1.75, mark=1, label_size=21, size=18.5)
photo_right(s, 'bushmills-french.jpg',
            'Bushmills distillery, County Antrim. Robert French, Lawrence Collection, National Library of '
            'Ireland. No known restrictions.', 1255 / 1056)
footer(s, 7)

# ---------------------------------------------------------------- 8 pour 2
pour_slide(8, 'Pour 2 of 4', ['Bushmills', '10 Year Old'],
           ['Malted barley only, distilled three times.', 'Put it beside the Redbreast and compare the weight.'],
           ['Bushmills,', 'County Antrim'], ['Single malt', 'Irish whiskey'], '40%', two_line_name=True)

# ---------------------------------------------------------------- 9 export markets
s = new_slide()
heading(s, 0.75, ['The export markets', 'close, 1920 to 1938'], size=36, w=6.7, h=1.3)
rows_card(s, X, 2.2, 6.7, [
    ('1920', 'Prohibition in the United States, until 1933.'),
    ('1922', 'The Irish Free State is founded.'),
    ('1932', 'Trade war with Britain. Tariffs both ways until 1938.'),
    ('1933', 'Repeal. Scotch blends are ready.'),
], label_w=1.15, row_h=1.0, mark=3, label_size=28, size=18)
photo_right(s, 'prohibition-sewer-1921.jpg',
            'Agents pour seized liquor into a New York sewer, about 1921. Library of Congress, public domain.',
            1255 / 1056)
footer(s, 9)

# ---------------------------------------------------------------- 10 1966 (big year, on paper)
s = new_slide()
heading(s, 0.75, 'The last three distilling firms in the Republic merge', size=30, w=CW, h=0.7)
text(s, 0.75, 1.55, 5.6, 2.1, '1966', size=150, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 3.65, 1.2, 0.045, fill=MARK_DEEP)
fx, fw, fr = 6.7, R - 6.7, 0.78
rrect(s, fx, 1.6, fw, fr * 3 + 0.1, r=0.26, fill=WHITE, line=HAIR)
for i, firm in enumerate(['John Jameson & Son', 'John Power & Son', 'Cork Distilleries Company']):
    yy = 1.65 + i * fr
    if i:
        line(s, fx + 0.3, yy, fx + fw - 0.3, yy, HAIR, 1.0)
    text(s, fx + 0.35, yy, fw - 0.7, fr, firm, size=22, font=SANS, bold=True, color=INK,
         anchor=MSO_ANCHOR.MIDDLE)
text(s, X, 4.6, CW, 0.5, 'The group is known today as Irish Distillers.', size=22, color=MUTE)
footer(s, 10)

# ---------------------------------------------------------------- 11 Dublin closes
s = new_slide()
heading(s, 0.85, 'Dublin closes and Midleton opens, 1971\u00a0to\u00a01976', size=36, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('1971', 'Bow Street stops distilling. Its production moves to John’s Lane.'),
    ('1975', 'A new distillery opens at Midleton, County Cork.'),
    ('1976', 'John’s Lane closes. No whiskey is distilled in Dublin.'),
], label_w=1.5, row_h=1.25, mark=2, label_size=32, size=22)
footer(s, 11)

# ---------------------------------------------------------------- 12 two distilleries (big number, on paper)
s = new_slide()
text(s, 0.75, 1.3, 3.2, 3.6, '2', size=260, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, X + 0.03, 5.0, 1.2, 0.045, fill=MARK_DEEP)
text(s, 4.3, 2.1, 8.2, 1.6, ['working distilleries on the', 'island by 1980'],
     size=40, font=SANS, bold=True, color=INK, ls=0.95)
text(s, 4.3, 3.85, 8.0, 1.4,
     ['Midleton and Bushmills, both owned by Irish Distillers.',
      'All new Irish whiskey was distilled at one of them.'], size=22, color=INK, ls=1.25)
footer(s, 12)

# ---------------------------------------------------------------- 13 pour 3
pour_slide(13, 'Pour 3 of 4', 'Powers Gold Label',
           ['Pot still whiskey blended with column-still grain whiskey, the mix John’s Lane once refused.',
            'Taste it after the Redbreast.'],
           ['Irish Distillers,', 'Midleton'], ['Blended', 'Irish whiskey'], '43.2%')

# ---------------------------------------------------------------- 14 the revival
s = new_slide()
heading(s, 0.85, 'The revival starts at Cooley in 1987', size=40, w=CW, h=0.9)
rows_card(s, X, 2.0, CW, [
    ('1987', 'John Teeling buys a former state potato-alcohol plant at Riverstown, County Louth, for a '
             'whiskey distillery.'),
    ('1993', 'Irish Distillers bids for Cooley. The Competition Authority blocks the takeover.'),
    ('2010s', 'New distilleries open across the island, Dublin included.'),
], label_w=1.75, row_h=1.3, mark=2, label_size=32, size=21)
footer(s, 14)

# ---------------------------------------------------------------- 15 pour 4
pour_slide(15, 'Pour 4 of 4', ['Connemara Original', 'Peated Single Malt'],
           ['Peat smoke and two distillations, both unusual in Irish whiskey when Cooley started.'],
           ['Cooley,', 'County Louth'], ['Peated single malt', 'Irish whiskey'], '40%', two_line_name=True)

# ---------------------------------------------------------------- 16 reading the label
s = new_slide()
heading(s, 0.85, 'Reading an Irish whiskey label', size=40, w=CW, h=0.9)
rows_card(s, X, 1.9, CW, [
    ('Irish whiskey', 'Distilled and aged at least three years on the island of Ireland.'),
    ('Single pot still', 'Malted and unmalted barley, pot stills, one distillery.'),
    ('Single malt', 'Malted barley only, pot stills, one distillery.'),
    ('Blended', 'A mix of two or more styles, usually with grain whiskey.'),
    ('Who made it', 'Many new brands buy whiskey in. Look for a distillery.'),
], label_w=3.0, row_h=0.92, label_size=22, size=20)
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
