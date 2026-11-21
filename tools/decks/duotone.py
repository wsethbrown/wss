"""Crop a photograph to a frame and, optionally, print it in the site's two inks.

    python3 -I tools/decks/duotone.py <in.jpg> <out.jpg> <width_in> <height_in> [--duotone] [--focus X,Y]

Crops to the width:height ratio of the frame it will fill on the slide (so wsskit.picture
does not stretch it), at 300 px per inch up to 1600 px on the long side. --focus picks the
part to keep, as fractions of the image (0.5,0.5 = centre; 0.5,0.2 = keep the top).
--duotone prints it greyscale in bottle green (#16332A) and cream (#F6F4EE), the way the
site's shared/_duotone partial does; good for old buildings and documents, poor for
bottles, whose labels people need to read.

A crop or duotone is a change to the image: say so in the image credits ("Cropped and
printed in two inks").
"""
import sys

from PIL import Image, ImageOps

INK = (0x16, 0x33, 0x2A)
CREAM = (0xF6, 0xF4, 0xEE)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 4:
        raise SystemExit(__doc__)
    src, dst, w_in, h_in = args[0], args[1], float(args[2]), float(args[3])
    focus = (0.5, 0.5)
    if '--focus' in sys.argv:
        fx, fy = sys.argv[sys.argv.index('--focus') + 1].split(',')
        focus = (float(fx), float(fy))
    im = Image.open(src).convert('RGB')
    long_px = min(1600, int(max(w_in, h_in) * 300))
    size = (long_px, int(long_px * h_in / w_in)) if w_in >= h_in else (int(long_px * w_in / h_in), long_px)
    im = ImageOps.fit(im, size, method=Image.LANCZOS, centering=focus)
    if '--duotone' in sys.argv:
        grey = ImageOps.autocontrast(ImageOps.grayscale(im), cutoff=1)
        im = ImageOps.colorize(grey, black=INK, white=CREAM)
    im.save(dst, quality=86, optimize=True, progressive=True)
    print('wrote %s (%d x %d)' % (dst, im.size[0], im.size[1]))


if __name__ == '__main__':
    main()
