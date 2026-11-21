"""Same as tools/decks/duotone.py, but takes the focus as a plain argument
(the kit's script counts the --focus value as a fifth positional and refuses).
    python3 -I crop.py in out w_in h_in fx fy [duotone]"""
import sys
from PIL import Image, ImageOps
INK = (0x16, 0x33, 0x2A); CREAM = (0xF6, 0xF4, 0xEE)
src, dst, w_in, h_in, fx, fy = sys.argv[1:7]
w_in, h_in = float(w_in), float(h_in)
im = Image.open(src).convert('RGB')
long_px = min(1600, int(max(w_in, h_in) * 300))
size = (long_px, int(long_px * h_in / w_in)) if w_in >= h_in else (int(long_px * w_in / h_in), long_px)
im = ImageOps.fit(im, size, method=Image.LANCZOS, centering=(float(fx), float(fy)))
if len(sys.argv) > 7:
    grey = ImageOps.autocontrast(ImageOps.grayscale(im), cutoff=1)
    im = ImageOps.colorize(grey, black=INK, white=CREAM)
im.save(dst, quality=86, optimize=True, progressive=True)
print('wrote %s (%d x %d)' % (dst, *im.size))
