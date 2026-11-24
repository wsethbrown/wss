"""Draw the two Mint Julep maps (no text: labels are real text on the slide) from Natural Earth data.

    python3 -I maps.py <mapdata_dir> <assets_dir>

Writes road_map.png (slide 3) and virginia_1789.png (slide 6) plus road_map.json and
virginia_1789.json: the pixel-fraction positions of every marker, so slides.py can place
labels exactly. Natural Earth is public domain. Equirectangular projection with the
longitude scaled by cos(mid-latitude).
"""
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

INK = (0x16, 0x33, 0x2A); PAPER = (0xF6, 0xF4, 0xEE); W100 = (0xEC, 0xEB, 0xE3); W200 = (0xDE, 0xDC, 0xCF)
HAIR = (0xC9, 0xCF, 0xC6); WHITE = (255, 255, 255); MARK_DEEP = (0xE6, 0x5C, 0x00); CREAM = (0xF6, 0xF4, 0xEE)
OAK_EDGE = (0x2F, 0x55, 0x46); SEA = (0xE4, 0xE9, 0xE3)

SS = 3  # supersample


class Proj:
    def __init__(self, lon0, lon1, lat0, lat1, width_px):
        self.lon0, self.lon1, self.lat0, self.lat1 = lon0, lon1, lat0, lat1
        self.k = math.cos(math.radians((lat0 + lat1) / 2))
        self.w = width_px * SS
        self.h = int(self.w * (lat1 - lat0) / ((lon1 - lon0) * self.k))

    def xy(self, lon, lat):
        return ((lon - self.lon0) / (self.lon1 - self.lon0) * self.w,
                (self.lat1 - lat) / (self.lat1 - self.lat0) * self.h)

    def frac(self, lon, lat):
        x, y = self.xy(lon, lat)
        return x / self.w, y / self.h


def rings(geom):
    t = geom['type']
    if t == 'Polygon':
        return [geom['coordinates']]
    if t == 'MultiPolygon':
        return geom['coordinates']
    return []


def draw_feature(d, p, geom, fill, outline=None, width=1):
    for poly in rings(geom):
        for i, ring in enumerate(poly):
            pts = [p.xy(x, y) for x, y in ring]
            if len(pts) < 3:
                continue
            d.polygon(pts, fill=fill if i == 0 else None)
            if outline:
                d.line(pts + [pts[0]], fill=outline, width=width, joint='curve')


def dashed(d, pts, color, width, dash, gap):
    """Dashed polyline through pts (pixel coords)."""
    on, left = True, dash
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        pos = 0.0
        while pos < seg:
            step = min(left, seg - pos)
            if on:
                a = pos / seg; b = (pos + step) / seg
                d.line([(x0 + (x1 - x0) * a, y0 + (y1 - y0) * a), (x0 + (x1 - x0) * b, y0 + (y1 - y0) * b)],
                       fill=color, width=width)
            pos += step; left -= step
            if left <= 1e-6:
                on = not on; left = dash if on else gap


def bezier(a, b, c, n=60):
    return [((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * b[0] + t * t * c[0],
             (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * b[1] + t * t * c[1]) for t in (i / n for i in range(n + 1))]


def dot(d, x, y, r, fill, ring=None, ring_w=0):
    if ring:
        d.ellipse([x - r - ring_w, y - r - ring_w, x + r + ring_w, y + r + ring_w], fill=ring)
    d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def road_map(md, out):
    land = json.loads((md / 'ne_50m_land.geojson').read_text())
    lakes = json.loads((md / 'ne_50m_lakes.geojson').read_text())
    p = Proj(-104, 62, 8, 62, 2400)
    im = Image.new('RGB', (p.w, p.h), SEA)
    d = ImageDraw.Draw(im)
    for f in land['features']:
        draw_feature(d, p, f['geometry'], WHITE, HAIR, 2 * SS)
    for f in lakes['features']:
        if (f['properties'].get('scalerank') or 9) <= 2:
            draw_feature(d, p, f['geometry'], SEA, HAIR, 1 * SS)
    stops = {
        'persia': (51.4, 32.7),      # Isfahan, roughly
        'levant': (35.5, 33.9),      # Beirut, roughly
        'andalus': (-4.8, 37.9),     # Cordoba, roughly
        'england': (-0.1, 51.5),     # London
        'virginia': (-76.7, 37.3),   # Williamsburg
        'kentucky': (-84.5, 38.0),   # Lexington, roughly
    }
    P = {k: p.xy(*v) for k, v in stops.items()}
    route = []
    route += bezier(P['persia'], p.xy(44, 37.5), P['levant'])
    route += bezier(P['levant'], p.xy(15, 34.0), P['andalus'])[1:]
    route += bezier(P['andalus'], p.xy(-11, 46), P['england'])[1:]
    route += bezier(P['england'], p.xy(-40, 52), P['virginia'])[1:]
    route += bezier(P['virginia'], p.xy(-80.5, 39.2), P['kentucky'])[1:]
    dashed(d, route, INK, 5 * SS, 15 * SS, 11 * SS)
    for k, (x, y) in P.items():
        if k == 'kentucky':
            dot(d, x, y, 13 * SS, INK, WHITE, 4 * SS)
            dot(d, x, y, 5 * SS, MARK_DEEP)
        else:
            dot(d, x, y, 10 * SS, MARK_DEEP, WHITE, 4 * SS)
    im = im.resize((p.w // SS, p.h // SS), Image.LANCZOS)
    im.save(out / 'road_map.png', optimize=True)
    pos = {k: p.frac(*v) for k, v in stops.items()}
    pos['_size'] = im.size
    (out / 'road_map.json').write_text(json.dumps(pos, indent=1))
    print('road_map.png', im.size)


def virginia_map(md, out):
    states = json.loads((md / 'ne_10m_admin_1_states_provinces_lakes.geojson').read_text())
    land = json.loads((md / 'ne_50m_land.geojson').read_text())
    p = Proj(-90.6, -74.6, 34.6, 42.2, 2400)
    im = Image.new('RGB', (p.w, p.h), SEA)
    d = ImageDraw.Draw(im)
    for f in land['features']:
        draw_feature(d, p, f['geometry'], W100)
    old_va = {'Kentucky', 'West Virginia', 'Virginia'}
    usa = [f for f in states['features'] if f['properties'].get('adm0_a3') == 'USA']
    near = [f for f in usa if f['properties']['name'] not in old_va]
    for f in near:
        draw_feature(d, p, f['geometry'], W100, WHITE, 3 * SS)
    for f in usa:
        if f['properties']['name'] in old_va:
            draw_feature(d, p, f['geometry'], INK)
    # modern lines inside 1789 Virginia, dashed cream
    for f in usa:
        if f['properties']['name'] in old_va:
            for poly in rings(f['geometry']):
                pts = [p.xy(x, y) for x, y in poly[0]]
                dashed(d, pts + [pts[0]], (0xB9, 0xC6, 0xBE), 3 * SS, 10 * SS, 8 * SS)
    # outer edge of 1789 Virginia, solid
    for f in usa:
        if f['properties']['name'] in old_va:
            for poly in rings(f['geometry']):
                pts = [p.xy(x, y) for x, y in poly[0]]
    sites = {
        'williamsburg': (-76.71, 37.27),
        'mecklenburg': (-78.36, 36.68),   # Boydton, Mecklenburg County seat
        'norfolk': (-76.29, 36.85),
    }
    # the circle around the citation sites
    cx, cy = p.xy(-77.35, 37.0)
    rx, ry = 2.05 / (p.lon1 - p.lon0) * p.w * p.k / p.k, 0.95 / (p.lat1 - p.lat0) * p.h
    rx = 2.05 / (p.lon1 - p.lon0) * p.w
    for i in range(7 * SS):
        d.ellipse([cx - rx - i / 2, cy - ry - i / 2, cx + rx + i / 2, cy + ry + i / 2], outline=MARK_DEEP)
    for k, v in sites.items():
        x, y = p.xy(*v)
        dot(d, x, y, 10 * SS, CREAM, MARK_DEEP, 5 * SS)
    im = im.resize((p.w // SS, p.h // SS), Image.LANCZOS)
    im.save(out / 'virginia_1789.png', optimize=True)
    pos = {k: p.frac(*v) for k, v in sites.items()}
    pos['circle'] = [p.frac(-77.35, 37.0), rx / p.w, ry / p.h]
    for name, ll in {'kentucky': (-85.6, 37.45), 'wv': (-80.6, 38.75), 'va': (-78.7, 37.7), 'ohio': (-82.7, 40.3),
                     'pennsylvania': (-77.6, 40.95), 'maryland': (-76.9, 39.45), 'tennessee': (-86.6, 35.75),
                     'northcarolina': (-79.4, 35.55), 'indiana': (-86.3, 39.9), 'illinois': (-89.3, 39.6)}.items():
        pos[name] = p.frac(*ll)
    pos['_size'] = im.size
    (out / 'virginia_1789.json').write_text(json.dumps(pos, indent=1))
    print('virginia_1789.png', im.size)


if __name__ == '__main__':
    md, out = Path(sys.argv[1]), Path(sys.argv[2])
    road_map(md, out)
    virginia_map(md, out)
