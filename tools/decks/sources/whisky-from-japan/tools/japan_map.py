"""Draw Japan's main islands (Natural Earth 1:10m, public domain, via world-atlas@2.0.2)
as a flat green shape on transparent ground. Prints the projection so slides.py can place
markers.   python3 -I japan_map.py <countries-10m.json> <out.png> <width_in> <height_in>"""
import json, math, sys
from PIL import Image, ImageDraw
src, out, W_IN, H_IN = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
LON0, LON1, LAT0, LAT1 = 129.2, 146.2, 30.9, 45.7
K = math.cos(math.radians(38.0))
d = json.load(open(src))
sc, tr = d['transform']['scale'], d['transform']['translate']
arcs = []
for a in d['arcs']:
    x = y = 0; pts = []
    for dx, dy in a:
        x += dx; y += dy
        pts.append((x * sc[0] + tr[0], y * sc[1] + tr[1]))
    arcs.append(pts)
def ring(ix):
    pts = []
    for i in ix:
        p = arcs[i] if i >= 0 else arcs[~i][::-1]
        pts.extend(p if not pts else p[1:])
    return pts
geom = [g for g in d['objects']['countries']['geometries'] if g.get('id') == '392'][0]
PX = 300
w, h = int(W_IN * PX), int(H_IN * PX)
# fit the box into w x h keeping aspect
bw, bh = (LON1 - LON0) * K, (LAT1 - LAT0)
s = min(w / bw, h / bh)
ox, oy = (w - bw * s) / 2, (h - bh * s) / 2
def proj(lon, lat):
    return (ox + (lon - LON0) * K * s, oy + (LAT1 - lat) * s)
im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
dr = ImageDraw.Draw(im)
for poly in geom['arcs']:
    outer = ring(poly[0])
    if max(p[1] for p in outer) < LAT0 or min(p[0] for p in outer) > LON1:
        continue
    dr.polygon([proj(*p) for p in outer], fill=(0xDE, 0xDC, 0xCF, 255))
    for hole in poly[1:]:
        dr.polygon([proj(*p) for p in ring(hole)], fill=(0, 0, 0, 0))
im.save(out)
print(json.dumps({'lon0': LON0, 'lat1': LAT1, 'k': K, 's_in': s / PX, 'ox_in': ox / PX, 'oy_in': oy / PX}))
