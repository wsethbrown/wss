"""Crop a bottle photograph to the pour slide's photo slot (3.4 x 5.3) and save it at 1020 x 1590.

    python3 -I tools/decks/crop_bottle.py <source image> <out.jpg> [cx cy height]

cx and cy are the centre of the crop as fractions of the image (default 0.5 0.5); height is the
crop's height as a fraction of the image's height (default 1.0). The crop is clamped to the image,
and narrowed if the image is not wide enough. Look at the result before using it.
"""
import sys
from PIL import Image, ImageOps

def main(a):
    src, out = a[0], a[1]
    cx, cy, hf = (float(v) for v in (a[2:5] if len(a) >= 5 else (0.5, 0.5, 1.0)))
    Image.MAX_IMAGE_PIXELS = None
    im = ImageOps.exif_transpose(Image.open(src)).convert('RGB')
    h = im.height * hf
    w = h * 3.4 / 5.3
    if w > im.width:
        w, h = im.width, im.width * 5.3 / 3.4
    x = min(max(cx * im.width - w / 2, 0), im.width - w)
    y = min(max(cy * im.height - h / 2, 0), im.height - h)
    crop = im.crop((int(x), int(y), int(x + w), int(y + h)))
    print('%s: %dx%d, crop %dx%d' % (src.split('/')[-1], im.width, im.height, crop.width, crop.height))
    crop.resize((1020, 1590), Image.LANCZOS).save(out, quality=90)

if __name__ == '__main__':
    main(sys.argv[1:])
