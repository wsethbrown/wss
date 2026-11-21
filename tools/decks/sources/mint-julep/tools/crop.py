"""Same as tools/decks/duotone.py, but --focus works (the kit's version counts the focus value as a
fifth positional argument and refuses). crop.py in out w_in h_in [--duotone] [--focus X,Y]"""
import sys
from PIL import Image, ImageOps
INK = (0x16, 0x33, 0x2A); CREAM = (0xF6, 0xF4, 0xEE)
a = sys.argv[1:]
focus = (0.5, 0.5)
if '--focus' in a:
    i = a.index('--focus'); fx, fy = a[i + 1].split(','); focus = (float(fx), float(fy)); del a[i:i + 2]
duo = '--duotone' in a
a = [x for x in a if x != '--duotone']
src, dst, w, h = a[0], a[1], float(a[2]), float(a[3])
im = Image.open(src).convert('RGB')
lp = min(1600, int(max(w, h) * 300))
size = (lp, int(lp * h / w)) if w >= h else (int(lp * w / h), lp)
im = ImageOps.fit(im, size, method=Image.LANCZOS, centering=focus)
if duo:
    im = ImageOps.colorize(ImageOps.autocontrast(ImageOps.grayscale(im), cutoff=1), black=INK, white=CREAM)
im.save(dst, quality=88, optimize=True, progressive=True)
print('wrote', dst, im.size)
