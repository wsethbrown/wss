"""The Rye From Lawrenceburg: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/examples/the-rye-from-lawrenceburg <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.
"""
from wsskit import *

# ---------------------------------------------------------------- 1 title
title_slide('The Rye From Lawrenceburg',
            'One Indiana distillery made the rye in a great many American bottles. Four of them, side by side.',
            series='The Whiskey Share Society  ·  A story in four glasses')

# ---------------------------------------------------------------- 2 start with the Bulleit
s = new_slide()
text(s, 0.85, 0.85, 6.6, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), ('Glass 1. Pour it now.', {})]],
     size=15, font=SANS, bold=True, color=INK)
heading(s, 1.35, 'Start with the Bulleit.', size=34, w=7.0, h=0.9)
text(s, 0.85, 2.55, 6.5, 3.6, [
    'This is Bulleit 95 Rye. It was distilled in Lawrenceburg, Indiana, and so were the other three glasses tonight.',
    'Taste it slowly. It is a very high-rye whiskey, and whatever spicy, grassy, herbal thing you find in it comes mostly from the grain.',
    [('Remember how it tastes. The other three glasses start from the same rye.', {'bold': True})],
], size=19, ls=1.25, space_after=12)
rrect(s, 7.95, 0.85, 4.53, 5.65, r=0.36, fill=WHITE, line=HAIR)
text(s, 8.35, 1.25, 3.8, 0.4, 'The recipe', size=14, font=SANS, bold=True, color=MUTE)
text(s, 8.35, 1.75, 3.8, 1.6, '95%', size=110, font=SANS, bold=True, color=INK, ls=0.9)
text(s, 8.4, 3.38, 3.8, 0.5, 'rye', size=26, italic=True, color=INK)
line(s, 8.4, 4.12, 12.08, 4.12, HAIR, 1.0)
text(s, 8.35, 4.3, 3.8, 0.9, '5%', size=54, font=SANS, bold=True, color=INK)
text(s, 8.4, 5.2, 3.8, 0.5, 'malted barley', size=22, italic=True, color=INK)
text(s, 8.4, 5.82, 3.8, 0.45, 'Many American ryes are just over half rye.', size=13, font=SANS, color=MUTE)
footer(s, 2)

# ---------------------------------------------------------------- 3 1847
s = new_slide()
text(s, 0.75, 0.9, 6.2, 2.2, '1847', size=150, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, 0.88, 3.25, 1.2, 0.045, fill=MARK_DEEP)
text(s, 0.85, 3.55, 5.6, 1.0, 'Lawrenceburg, Indiana', size=26, font=SANS, bold=True, color=INK)
text(s, 0.85, 4.1, 5.6, 0.6, 'The town where the story starts.', size=18, italic=True, color=MUTE)
heading(s, 1.15, 'George Ross starts a rye distillery.', size=34, x=7.1, w=5.4, h=1.4)
text(s, 7.1, 2.75, 5.35, 3.6, [
    'It comes to be called the Rossville Union Distillery.',
    'The trade press keeps his name, his town and his trade, and very little else about him.',
    [('The name comes back with the last glass.', {'bold': True})],
], size=19, ls=1.25, space_after=12)
footer(s, 3)

# ---------------------------------------------------------------- 4 1933 Seagram
s = new_slide()
text(s, 0.75, 0.9, 6.0, 2.2, '1933', size=150, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, 0.88, 3.25, 1.2, 0.045, fill=MARK_DEEP)
text(s, 0.85, 3.55, 5.4, 0.6, 'Prohibition ends. Seagram buys the distillery.', size=24, font=SANS, bold=True,
     color=INK, ls=1.0)
text(s, 0.85, 4.55, 5.2, 1.9,
     'For most of the next seventy years it is a Seagram workhorse, making whiskey in volume, much of it never meant to be drunk on its own.',
     size=18, ls=1.25)
picture(s, A / 'seagram_duotone.jpg', 6.58, 0.85, 5.9, 4.6, radius_in=0.26)
text(s, 6.58, 5.58, 5.9, 0.7,
     'Seagram’s, Ridge Avenue, Lawrenceburg. Photograph: Indiana Landmarks, CC BY 4.0, via Wikimedia Commons.',
     size=11, font=SANS, color=MUTE, ls=1.1)
footer(s, 4)

# ---------------------------------------------------------------- 5 a rye made to disappear
s = new_slide(INK)
text(s, 0.85, 0.85, 6.0, 0.4, 'The Seagram years', size=15, font=SANS, bold=True, color=CREAM_MUTE)
heading(s, 1.3, 'A rye made for blending.', size=42, color=CREAM, w=6.4, h=1.5)
text(s, 0.85, 2.95, 6.0, 3.6, [
    'Seagram sold blends, among them 7 Crown and 5 Crown. A blend needs a little of something with a lot of flavour to give it character.',
    'Larry Ebersold, who started distilling at Lawrenceburg in 1972, settled on 95% rye and 5% malted barley. A little of it goes a long way.',
], size=19, color=CREAM, ls=1.25, space_after=12)
rrect(s, 7.45, 0.85, 5.03, 5.65, r=0.4, fill=OAK, line=OAK_EDGE)
rect(s, 7.95, 1.55, 0.9, 0.045, fill=MARK)
text(s, 7.95, 1.85, 4.1, 2.6, 'For decades most of it went into blends.', size=32, italic=True,
     color=CREAM, ls=1.15)
text(s, 7.95, 4.75, 4.1, 1.3,
     'Very high-rye mashes foam and gum up the works. One writer credits the Lawrenceburg equipment with handling them better than most.',
     size=14, font=SANS, color=CREAM_MUTE, ls=1.2)
footer(s, 5, dark=True)

# ---------------------------------------------------------------- 6 nearly the end
s = new_slide()
heading(s, 0.85, 'Nearly the end.', size=40, h=0.9)
text(s, 0.85, 1.8, 11.6, 0.5, 'After Seagram, the plant changes hands three times in eleven years.',
     size=19, italic=True, color=MUTE)
stops = [
    ('c. 2000', 'Pernod Ricard', 'Seagram is broken up. The Lawrenceburg plant goes to Pernod Ricard.'),
    ('19 April 2006', 'Closure announced', 'Pernod Ricard says it will close the distillery.'),
    ('2007', 'Lawrenceburg Distillers Indiana', 'Sold instead to CL Financial of Trinidad and Tobago, which collapses in the 2008 crisis.'),
    ('2011', 'MGP Ingredients', 'A Kansas company buys it, and sells its whiskey to other brands.'),
]
x0, x1, ty = 0.85, 12.48, 3.45
line(s, x0 + 0.1, ty, x1 - 0.1, ty, INK, 1.5)
cw = (x1 - x0) / 4
for i, (yr, name, body) in enumerate(stops):
    cx = x0 + i * cw
    dot(s, cx + 0.12, ty, 0.24, MARK_DEEP if i in (1, 3) else INK)
    text(s, cx, 2.75, cw - 0.3, 0.45, yr, size=17, font=SANS, bold=True, color=INK)
    text(s, cx, 3.8, cw - 0.35, 0.8, name, size=19, font=SANS, bold=True, color=INK, ls=1.0)
    text(s, cx, 4.65, cw - 0.4, 2.0, body, size=16, ls=1.2)
footer(s, 6)

# ---------------------------------------------------------------- 7 the rye revival
s = new_slide()
heading(s, 0.8, 'One rye, many labels.', size=38, h=0.8, w=7)
text(s, 0.85, 1.62, 11.6, 0.6,
     'New rye brands needed aged whiskey faster than they could make it. Lawrenceburg had it.',
     size=18, italic=True, color=MUTE)
cx, cy = SLIDE_W / 2, 4.2
pw, ph = 3.3, 1.25
brands = [
    ('Bulleit', 'Kentucky', -4.25, -1.5), ('George Dickel', 'Tennessee', -4.25, -0.5), ('Templeton', 'Iowa', -4.25, 0.5),
    ('Angel\u2019s Envy', None, -4.25, 1.5),
    ('Smooth Ambler', 'West Virginia', 4.25, -1.5), ('High West', 'Utah', 4.25, -0.5), ('Redemption', None, 4.25, 0.5),
    ('Filibuster', None, 4.25, 1.5),
]
chip_w, chip_h = 2.9, 0.8
for name, state, dx, dy in brands:
    bx, by = cx + dx, cy + dy
    line(s, cx, cy, bx, by, W200, 1.25)
for name, state, dx, dy in brands:
    bx, by = cx + dx, cy + dy
    rrect(s, bx - chip_w / 2, by - chip_h / 2, chip_w, chip_h, r=0.16, fill=WHITE, line=HAIR)
    if state:
        text(s, bx - chip_w / 2 + 0.2, by - 0.3, chip_w - 0.4, 0.34, name, size=15, font=SANS, bold=True,
             color=INK, align=PP_ALIGN.CENTER)
        text(s, bx - chip_w / 2 + 0.2, by + 0.04, chip_w - 0.4, 0.3, state, size=12.5, font=SANS, color=MUTE,
             align=PP_ALIGN.CENTER)
    else:
        text(s, bx - chip_w / 2 + 0.2, by - 0.4, chip_w - 0.4, 0.8, name, size=15, font=SANS, bold=True,
             color=INK, align=PP_ALIGN.CENTER, anchor=MSO_ANCHOR.MIDDLE)
rrect(s, cx - pw / 2, cy - ph / 2, pw, ph, r=0.3, fill=INK)
dot(s, cx - pw / 2 + 0.38, cy - 0.17, 0.13, MARK)
text(s, cx - pw / 2 + 0.55, cy - 0.38, pw - 0.7, 0.42, 'Lawrenceburg', size=20, font=SANS, bold=True, color=CREAM)
text(s, cx - pw / 2 + 0.55, cy + 0.04, pw - 0.7, 0.36, 'Indiana, 95% rye', size=14, font=SANS, color=CREAM_MUTE)
text(s, 0.85, 6.4, 11.6, 0.3, 'Some of the brands reported to have bottled Lawrenceburg rye. Far from a complete list.',
     size=11, font=SANS, color=MUTE)
footer(s, 7)


# ---------------------------------------------------------------- 8-10 the first three glasses
glass_slide(8, 'Glass 1, the one you have been drinking', 'Bulleit 95 Rye',
            'Distilled in Lawrenceburg  ·  bottled in Kentucky  ·  90 proof  ·  about $30',
            ['Launched in 2011, distilled to Bulleit’s own specification. The recipe is printed on the front: 95.',
             'Bulleit’s own Kentucky distilleries make bourbon. Every Bulleit rye has been made on this Indiana recipe, by choice.'],
            [('Distilled', 'Lawrenceburg, Indiana'), ('The brand', 'Specification, age, proof, bottling in Kentucky'),
             ('Look for', 'Rye spice, mint, a grassy edge')],
            'Now that you know what it is, what do you taste that you would call “rye”?',
            photo='bulleit95.jpg',
            credit='Photograph: David (brokentaco), CC BY 2.0, via Wikimedia Commons.')

glass_slide(9, 'Glass 2, pour now', 'George Dickel Rye',
            'Distilled in Lawrenceburg  ·  a Tennessee house  ·  90 proof  ·  about $25',
            ['The same 95% rye as glass 1, with a step from Dickel’s own tradition.',
             'Dickel says the rye is chilled, then filtered through charcoal made from sugar maple, the way its Tennessee whisky is. Where that happens, accounts disagree.'],
            [('Distilled', 'Lawrenceburg, Indiana'), ('The brand', 'Chill and sugar-maple charcoal'),
             ('Look for', 'Is it rounder or softer than glass 1?')],
            'Put glasses 1 and 2 side by side. Is the charcoal doing anything you can taste?')

glass_slide(10, 'Glass 3, pour now', 'Templeton Straight Rye',
            'Distilled in Lawrenceburg  ·  an Iowa town’s name  ·  90 proof  ·  about $30',
            ['Founded in 2006 on a town legend: Prohibition bootleg rye from Templeton, Iowa, the story goes.',
             'A 2015 settlement put “Distilled in Indiana” on the label. In 2018 Templeton opened its own Iowa distillery; its first Iowa rye came out in October 2025.'],
            [('Distilled', 'Lawrenceburg, for this bottle'), ('The brand', 'At least four years, 90 proof, bottled in Iowa'),
             ('Now', 'Making its own rye in Templeton')],
            'Three glasses, one recipe. Which one would you buy again?',
            photo='templeton.jpg',
            credit='Pictured: Templeton Rye 6 Year. Photograph: David (brokentaco), CC BY 2.0, via Wikimedia Commons.')

# ---------------------------------------------------------------- 11 back label
s = new_slide()
text(s, 0.85, 0.85, 6.2, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), ('Pick up any bottle and turn it round', {})]],
     size=15, font=SANS, bold=True, color=INK)
heading(s, 1.3, 'Reading the back label.', size=40, w=6.6, h=1.0)
text(s, 0.85, 2.45, 6.0, 3.6, [
    'Federal rules say most American whiskies must show the state where they were first distilled.',
    'When the address on the label is in one state and the whiskey was distilled in another, that state has to appear too. It is usually on the back, in small type.',
    [('Every approved label, front and back, is public in the TTB’s COLA registry.', {'bold': True})],
], size=18, ls=1.25, space_after=11)
rrect(s, 7.6, 0.85, 4.88, 5.0, r=0.3, fill=WHITE, line=HAIR)
text(s, 7.95, 1.15, 4.2, 0.35, 'Where to look', size=13, font=SANS, bold=True, color=MUTE)
rows = [('Straight Rye Whiskey', 'the class and type', False), ('Distilled in Indiana', 'the state of distillation', True),
        ('Bottled by …, Kentucky', 'the company’s address', False), ('45% alc./vol. (90 proof)', 'the strength', False)]
yy = 1.65
for big, small, hot in rows:
    if hot:
        rrect(s, 7.85, yy - 0.08, 4.38, 0.98, r=0.16, fill=W100)
        dot(s, 8.07, yy + 0.2, 0.11, MARK_DEEP)
    text(s, 8.25, yy, 3.85, 0.4, big, size=18, font=SANS, bold=True, color=INK)
    text(s, 8.25, yy + 0.42, 3.85, 0.35, small, size=13, italic=True, color=MUTE)
    yy += 1.02
text(s, 7.6, 5.98, 4.88, 0.6, 'An illustration of the lines to find, not any one brand’s label. Rule: 27 CFR 5.66(f).',
     size=11, font=SANS, color=MUTE, ls=1.1)
footer(s, 11)

# ---------------------------------------------------------------- 12 Rossville Union
glass_slide(12, 'Glass 4, pour now', 'Rossville Union Straight Rye',
            'Distilled in Lawrenceburg  ·  the distillery’s own name  ·  94 proof  ·  about $40',
            ['In May 2018 the distillery put out its first rye under its own label, and reached back for George Ross’s old name.',
             'In 2021 the plant itself became Ross & Squibb Distillery. This rye blends its 95% recipe with a 51% rye.'],
            [('Distilled', 'Lawrenceburg, Indiana'), ('The brand', 'The house blend: 95% and 51% rye'),
             ('The name', 'For the first time tonight, front label and still agree')],
            'After three glasses of the 95%, what does the 51% rye add?')

# ---------------------------------------------------------------- 13 what came next
s = new_slide()
heading(s, 0.85, 'Where the brands are now.', size=40, w=6.2, h=1.5)
text(s, 0.85, 2.5, 5.2, 3.6, [
    'The rye made for Seagram’s blends is now sold under its own name and many others.',
    'Several of those brands now distil their own.',
], size=20, italic=True, ls=1.3, space_after=14)
rrect(s, 6.55, 0.85, 5.93, 5.65, r=0.3, fill=WHITE, line=HAIR)
items = [
    ('Templeton', 'Its own distillery in Iowa since 2018. First Iowa-made rye, October 2025.'),
    ('High West', 'Blends its own Utah rye with Indiana’s, keeping its own share under half.'),
    ('Bulleit', 'Makes bourbon in Kentucky and keeps its rye from Indiana.'),
    ('The owner', 'On 2 November 2026, MGP Ingredients renamed itself Sempreon.'),
]
yy = 1.1
for i, (k, v) in enumerate(items):
    if i:
        line(s, 6.9, yy - 0.12, 12.13, yy - 0.12, HAIR, 1.0)
    text(s, 6.9, yy, 1.7, 0.5, k, size=16, font=SANS, bold=True, color=INK)
    text(s, 8.65, yy, 3.55, 1.2, v, size=15.5, ls=1.2)
    yy += 1.3
footer(s, 13)

# ---------------------------------------------------------------- 14 Sláinte
slainte_slide('One distillery, four glasses. To George Ross, to Larry '
              'Ebersold, and to whoever is running the stills in Lawrenceburg tonight.')
