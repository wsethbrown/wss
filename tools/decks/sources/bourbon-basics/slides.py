"""Bourbon Basics: slide by slide.

Built by tools/decks/build.py, which sets up the kit first:
    python3 -I tools/decks/build.py tools/decks/sources/bourbon-basics <out_root>
Slide copy lives here; the script for the notes fields comes from speaker-notes.md.
Slide n here must be [SLIDE n] there.
"""
from wsskit import *


def kicker(s, t, x=0.85, y=0.85, w=7.0):
    text(s, x, y, w, 0.4, [[('●  ', {'color': MARK_DEEP, 'size': 12}), (t, {})]],
         size=15, font=SANS, bold=True, color=INK)


def credit(s, x, y, w, t):
    text(s, x, y, w, 0.4, t, size=9.5, font=SANS, color=MUTE, ls=1.05)


# ---------------------------------------------------------------- 1 title
s = new_slide(INK)
picture(s, LOGO_CREAM, 0.85, 0.75, 2.2, 2.2 * LOGO_RATIO)
text(s, 0.85, 2.95, 6.2, 1.0, 'Bourbon Basics', size=56, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, 0.88, 4.12, 0.9, 0.045, fill=MARK)
text(s, 0.85, 4.35, 5.9, 1.3, 'Four bourbons, and what the words on their labels mean.',
     size=20, italic=True, color=CREAM_MUTE, ls=1.2)
text(s, 0.85, 6.3, 6.2, 0.35, 'The Whiskey Share Society  ·  Four pours, about 45 minutes',
     size=11, font=SANS, color=CREAM_MUTE)
picture(s, A / 'rickhouse-title.jpg', 7.58, 0.6, 4.9, 5.75, radius_in=0.3)
text(s, 7.58, 6.43, 4.9, 0.4,
     'A rickhouse at Woodford Reserve. Ken Thomas, public domain, via Wikimedia Commons. Cropped and printed in two inks.',
     size=9.5, font=SANS, color=CREAM_MUTE, ls=1.05)

# ---------------------------------------------------------------- 2 glass 1
glass_slide(2, 'Glass 1', 'Maker’s Mark',
            'Loretto, Kentucky  ·  90 proof  ·  about $30',
            ['The label says “Kentucky Straight Bourbon Whisky”.',
             'The second grain in its recipe is wheat.'],
            [('The word', 'Bourbon'), ('Second grain', 'Wheat'), ('Age on the label', 'None')],
            photo='makers-mark-crop.jpg',
            credit='Photograph: U.S. National Archives, public domain, via Wikimedia Commons. Cropped.')

# ---------------------------------------------------------------- 3 how to taste
s = new_slide()
heading(s, 0.85, 'How to taste it.', size=40, w=6.6, h=1.0)
steps = ['Lift the glass until you can smell it, and stop there.',
         'Breathe normally. What else smells like this?',
         'Take a small sip and hold it. Then take a second.',
         'Too hot? Add a few drops of water.']
yy = 2.15
for i, t in enumerate(steps, 1):
    text(s, 0.85, yy - 0.06, 0.6, 0.6, str(i), size=30, font=SANS, bold=True, color=MARK_DEEP)
    text(s, 1.55, yy, 5.6, 0.9, t, size=20, ls=1.2)
    yy += 1.0
picture(s, A / 'tasting.jpg', 7.95, 0.85, 4.53, 3.75, radius_in=0.26)
credit(s, 7.95, 4.7, 4.53, 'Photograph: Lord van Tasm, CC BY-SA 3.0, via Wikimedia Commons. Cropped.')
footer(s, 3)

# ---------------------------------------------------------------- 4 what bourbon means
s = new_slide()
heading(s, 1.0, 'What “bourbon” means.', size=40, w=11.6, h=1.0)
rules = [('U.S.', 'Made in the United States'),
         ('51%', 'At least 51% corn'),
         ('160', 'Distilled to no more than 160 proof'),
         ('New oak', 'Aged in new, charred oak barrels, filled at no more than 125 proof'),
         ('80', 'Bottled at 80 proof or more'),
         ('Nothing', 'No coloring or flavoring added')]
cw, ch, gx, gy = 3.72, 1.55, 0.22, 0.2
for i, (big, small) in enumerate(rules):
    x = 0.85 + (i % 3) * (cw + gx)
    y = 2.45 + (i // 3) * (ch + gy)
    rrect(s, x, y, cw, ch, r=0.22, fill=WHITE, line=HAIR)
    text(s, x + 0.3, y + 0.16, cw - 0.6, 0.7, big, size=34, font=SANS, bold=True, color=INK)
    text(s, x + 0.3, y + 0.86, cw - 0.6, 0.65, small, size=14.5, color=INK, ls=1.1)
rrect(s, 0.85, 6.0, 11.6, 0.62, r=0.18, fill=W100)
text(s, 1.15, 6.0, 7.0, 0.62, 'There is no minimum age.', size=17, font=SANS, bold=True, color=INK,
     anchor=MSO_ANCHOR.MIDDLE)
text(s, 8.15, 6.0, 4.0, 0.62, 'Rule: 27 CFR 5.143', size=11, font=SANS, color=MUTE,
     anchor=MSO_ANCHOR.MIDDLE, align=PP_ALIGN.RIGHT)
footer(s, 4)

# ---------------------------------------------------------------- 5 not only Kentucky
s = new_slide()
heading(s, 0.85, 'It does not have to come from Kentucky.', size=38, w=6.4, h=2.0)
text(s, 0.85, 3.05, 6.2, 3.4, [
    'Federal rules do not mention Kentucky. Bourbon can be made in any state.',
    [('A state’s name beside “bourbon” means it was distilled and aged in that state.', {'bold': True})],
], size=20, ls=1.25, space_after=14)
rrect(s, 7.6, 0.85, 4.88, 5.65, r=0.4, fill=OAK, line=OAK_EDGE)
text(s, 8.1, 1.3, 3.9, 1.5, '1964', size=88, font=SANS, bold=True, color=CREAM, ls=0.9)
rect(s, 8.12, 2.95, 0.9, 0.045, fill=MARK)
text(s, 8.1, 3.25, 3.9, 2.0, 'Congress calls bourbon “a distinctive product of the United States”.',
     size=24, italic=True, color=CREAM, ls=1.15)
text(s, 8.1, 5.45, 3.9, 0.6, 'Senate Concurrent Resolution 19, May 1964', size=14, font=SANS, color=CREAM_MUTE)
footer(s, 5)

# ---------------------------------------------------------------- 6 the second grain
s = new_slide()
heading(s, 0.85, 'The second grain.', size=40, w=11.6, h=1.0)
text(s, 0.85, 1.75, 11.6, 0.5, 'At least 51% corn. The rest is the distiller’s choice.', size=20, italic=True, color=MUTE)
cols = [('Wheat', 'Softer and sweeter.', 'Glass 1', '70% corn, 16% wheat, 14% malted barley.',
         'Source: Maker’s Mark.'),
        ('Rye', 'Pepper and cinnamon.', 'Glass 2', 'Reported as about 27% rye.',
         'The label says “High Rye Mash Bill”.')]
for i, (grain, says, glass, recipe, note) in enumerate(cols):
    x = 0.85 + i * 5.91
    rrect(s, x, 2.6, 5.69, 3.9, r=0.3, fill=WHITE, line=HAIR)
    text(s, x + 0.4, 2.85, 4.9, 1.0, grain, size=54, font=SANS, bold=True, color=INK, ls=0.9)
    text(s, x + 0.4, 3.85, 4.9, 0.5, says, size=24, italic=True, color=INK)
    line(s, x + 0.4, 4.6, x + 5.29, 4.6, HAIR, 1.0)
    text(s, x + 0.4, 4.78, 4.9, 0.35, glass, size=13, font=SANS, bold=True, color=MUTE)
    text(s, x + 0.4, 5.13, 4.9, 0.5, recipe, size=17.5, color=INK)
    text(s, x + 0.4, 5.72, 4.9, 0.4, note, size=13, font=SANS, color=MUTE)
footer(s, 6)

# ---------------------------------------------------------------- 7 glass 2
glass_slide(7, 'Glass 2', 'Old Grand-Dad Bonded',
            'Made by Jim Beam in Kentucky  ·  100 proof  ·  about $25',
            ['The second grain is rye, where glass 1 has wheat. It is 100 proof, where glass 1 is 90.',
             [('The label says “Bonded”. The rule behind that word dates from 1897.', {'bold': True})]],
            [('The word', 'Bonded'), ('Second grain', 'Rye'), ('Age', 'At least four years')],
            photo='old-grand-dad-crop.jpg',
            credit='Pictured: an older 86 proof Old Grand-Dad, not the Bonded. Photograph: rick, CC BY 2.0, via Flickr. Cropped.')

# ---------------------------------------------------------------- 8 before the rules
s = new_slide()
text(s, 0.75, 0.9, 6.2, 2.2, '1853', size=150, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, 0.88, 3.25, 1.2, 0.045, fill=MARK_DEEP)
text(s, 0.85, 3.55, 5.6, 1.0, 'Before the rules', size=26, font=SANS, bold=True, color=INK)
text(s, 0.85, 4.1, 5.6, 0.6, 'From a manual for rectifiers, New York', size=18, italic=True, color=MUTE)
heading(s, 0.95, 'A published recipe for “Old Bourbon Whiskey” with no bourbon in it.', size=30, x=7.1, w=5.4, h=1.7)
text(s, 7.1, 2.75, 5.35, 2.4, [
    'Neutral spirit, water, strong tea and oil of wintergreen, colored with cochineal and burnt sugar.',
    'Distillers sold whiskey by the barrel. Rectifiers bought spirit, then blended, colored and flavored it. The trade was legal and licensed.',
], size=15.5, ls=1.2, space_after=8)
rrect(s, 7.1, 4.7, 5.38, 1.85, r=0.26, fill=WHITE, line=HAIR)
text(s, 7.4, 4.85, 4.8, 1.1,
     '“The thirsty individual who takes his glass of whiskey at any of even the first-class public bars ... does not know what he drinks.”',
     size=14.5, italic=True, color=INK, ls=1.15)
text(s, 7.4, 5.9, 4.8, 0.55, 'Joseph Fleischman, The Art of Blending and Compounding Liquors and Wines, 1885',
     size=11.5, font=SANS, color=MUTE, ls=1.1)
footer(s, 8)

# ---------------------------------------------------------------- 9 1897
s = new_slide()
text(s, 0.75, 0.9, 6.2, 2.2, '1897', size=150, font=SANS, bold=True, color=INK, ls=0.9)
rect(s, 0.88, 3.25, 1.2, 0.045, fill=MARK_DEEP)
text(s, 0.85, 3.55, 5.6, 1.0, 'The Bottled-in-Bond Act', size=26, font=SANS, bold=True, color=INK)
text(s, 0.85, 4.1, 5.6, 0.6, 'Approved 3 March 1897', size=18, italic=True, color=MUTE)
picture(s, A / 'taylor-crop.jpg', 0.85, 4.85, 1.3, 1.65, radius_in=0.16)
text(s, 2.35, 5.0, 3.6, 1.0, 'Col. E. H. Taylor Jr., a Kentucky distiller. Historians credit him with pushing for the Act.',
     size=13, font=SANS, color=MUTE, ls=1.15)
credit(s, 2.35, 5.95, 3.9, 'Portrait: Press Reference Book of Prominent Kentuckians, 1916. Public domain.')
heading(s, 1.15, 'Congress lets distillers bottle whiskey “in bond”.', size=30, x=7.1, w=5.4, h=1.3)
text(s, 7.1, 2.55, 5.35, 2.9, [
    'One distillery, one season',
    'Nothing added but water',
    '100 proof, at least four years old',
    'Bottled with a government officer present',
    'A stamp over the cork naming the real distiller',
], size=18, ls=1.15, space_after=7)
rrect(s, 7.1, 5.3, 5.38, 1.25, r=0.22, fill=W100)
text(s, 7.4, 5.3, 4.8, 1.25, [[('“Bonded” on a label today:  ', {'font': SANS, 'bold': True, 'size': 13}),
                              ('one distillery, one season, at least four years, exactly 100 proof.', {})]],
     size=15.5, color=INK, ls=1.15, anchor=MSO_ANCHOR.MIDDLE)
footer(s, 9)

# ---------------------------------------------------------------- 10 straight
s = new_slide()
heading(s, 0.85, 'What “straight” means.', size=40, w=7.0, h=1.0)
rows = [('1906', 'The Pure Food and Drugs Act. The argument begins over what may be called whiskey.'),
        ('1909', 'President Taft keeps “straight”, “bourbon” and “rye” for whiskey that is aged and unmixed.'),
        ('Today', 'Straight means at least two years in the barrel. Under four years, the label must give the age. '
                  'A stated age is the youngest whiskey in the bottle.')]
rrect(s, 0.85, 2.05, 7.0, 4.5, r=0.3, fill=WHITE, line=HAIR)
yy = 2.3
for i, (k, v) in enumerate(rows):
    if i:
        line(s, 1.2, yy - 0.12, 7.5, yy - 0.12, HAIR, 1.0)
    text(s, 1.2, yy, 1.5, 0.5, k, size=22, font=SANS, bold=True, color=INK)
    text(s, 2.75, yy + 0.02, 4.8, 1.6, v, size=16, ls=1.2)
    yy += 1.2 if i < 1 else 1.25
picture(s, A / 'wiley-crop.jpg', 8.25, 0.85, 4.23, 3.1, radius_in=0.26)
rrect(s, 8.25, 4.15, 4.23, 2.15, r=0.26, fill=WHITE, line=HAIR)
text(s, 8.55, 4.33, 3.65, 1.2, '“I am a rectifier now; I have taken out my license.”', size=18, italic=True,
     color=INK, ls=1.15)
text(s, 8.55, 5.3, 3.65, 0.95,
     'Harvey Wiley, 1906. He was mixing a whiskey from alcohol, caramel and flavoring in front of a House committee.',
     size=11.5, font=SANS, color=MUTE, ls=1.12)
credit(s, 8.25, 6.4, 4.23, 'Harvey W. Wiley in later life. Photograph: Harris & Ewing, Library of Congress.')
footer(s, 10)

# ---------------------------------------------------------------- 11 glass 3
glass_slide(11, 'Glass 3', 'Knob Creek 9 Year',
            'Clermont, Kentucky  ·  100 proof  ·  about $37',
            ['The label says “Kentucky Straight Bourbon Whiskey” and “Aged Nine Years”. Nothing in the bottle is younger than nine.',
             'Same proof as glass 2, from the same company. Glass 2 is at least four years old.'],
            [('The words', 'Straight, Aged Nine Years'), ('Age', 'At least nine years'),
             ('The number', 'Off the label in 2016, back in 2020')],
            photo='knob-creek-crop.jpg',
            credit='Pictured: an older Knob Creek label. Photograph: Craiglduncan, CC BY-SA 3.0, via Wikimedia Commons.')

# ---------------------------------------------------------------- 12 the barrel
s = new_slide()
heading(s, 1.0, 'Whiskey goes into the barrel clear.', size=38, w=6.6, h=1.6)
text(s, 0.85, 3.0, 6.3, 3.6, [
    'All of the color comes from the wood. Bourbon cannot have color added.',
    'The vanilla and caramel flavors come from the wood under the char.',
    'About 6% is lost in the first year and 3% a year after that (Heaven Hill’s figures).',
    'On hot upper floors the proof goes up. On cool lower floors it goes down.',
], size=17.5, ls=1.22, space_after=10)
picture(s, A / 'rickhouse-crop.jpg', 7.75, 0.85, 4.73, 2.55, radius_in=0.26)
picture(s, A / 'barrel-char-crop.jpg', 7.75, 3.55, 4.73, 2.55, radius_in=0.26)
credit(s, 7.75, 6.2, 4.73, 'Top: a rickhouse at Woodford Reserve. Ken Thomas, public domain. Bottom: a barrel being charred at Old Forester. King of Hearts, CC BY-SA 4.0. Both via Wikimedia Commons, cropped.')
footer(s, 12)

# ---------------------------------------------------------------- 13 words with rules, and without
s = new_slide()
heading(s, 0.85, 'Label words with a federal rule, and without.', size=38, w=11.6, h=1.0)
cols = [('A federal rule', ['Bourbon', 'Straight', 'Bonded', 'An age', 'Barrel proof'], WHITE, 1.85),
        ('No federal definition', ['Small batch', 'Single barrel', 'Reserve', 'Handmade'], W100, 1.85)]
for i, (label, words, fill, y0) in enumerate(cols):
    x = 0.85 + i * 5.91
    rrect(s, x, y0, 5.69, 3.6, r=0.3, fill=fill, line=HAIR)
    text(s, x + 0.4, y0 + 0.25, 4.9, 0.4, label, size=14, font=SANS, bold=True, color=MUTE)
    text(s, x + 0.4, y0 + 0.75, 4.9, 3.2, words, size=26, font=SANS, bold=True, color=INK, ls=1.0, space_after=6)
text(s, 0.85, 5.75, 11.6, 0.5, 'No rule says how small a small batch is.',
     size=17, italic=True, color=MUTE)
footer(s, 13)

# ---------------------------------------------------------------- 14 glass 4
glass_slide(14, 'Glass 4', 'Wild Turkey Rare Breed',
            'Lawrenceburg, Kentucky  ·  116.8 proof  ·  about $55',
            ['“Barrel Proof” means bottled within two degrees of proof of what came out of the barrel.',
             'This bottle is 116.8 proof, the strongest of the four.'],
            [('The words', 'Barrel Proof'), ('Strength', '58.4% alcohol'), ('Age on the label', 'None')],
            photo='rare-breed-crop.jpg',
            credit='Pictured: the 70 cl export bottle. Photograph: Brett Jordan, CC BY 2.0, via Flickr. Cropped.')

# ---------------------------------------------------------------- 15 what the four labels say
s = new_slide()
heading(s, 0.85, 'What the four labels say.', size=40, w=11.6, h=1.0)
rrect(s, 0.85, 1.9, 11.63, 4.0, r=0.3, fill=WHITE, line=HAIR)
rows = [('Maker’s Mark', '“Kentucky Straight Bourbon Whisky”',
         'At least 51% corn, new charred oak, at least two years, nothing added.'),
        ('Old Grand-Dad', '“Bonded”', 'One distillery, one season, at least four years, 100 proof.'),
        ('Knob Creek', '“Aged Nine Years”', 'Nothing in the bottle is younger than nine.'),
        ('Rare Breed', '“Barrel Proof”', 'The strength it came out of the barrel.')]
yy = 2.12
for i, (name, words, means) in enumerate(rows):
    if i:
        line(s, 1.2, yy - 0.13, 12.13, yy - 0.13, HAIR, 1.0)
    text(s, 1.2, yy, 2.4, 0.5, name, size=17, font=SANS, bold=True, color=INK)
    text(s, 3.65, yy, 3.6, 0.8, words, size=17, italic=True, color=INK, ls=1.1)
    text(s, 7.35, yy, 4.8, 0.8, means, size=15.5, color=INK, ls=1.15)
    yy += 0.95
footer(s, 15)

# ---------------------------------------------------------------- 16 Sláinte
slainte_slide('To the people who made these four bourbons.')
