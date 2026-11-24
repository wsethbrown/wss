#!/bin/bash
# Render the default link-preview card to a 1200x630 PNG with headless Chrome.
#
#   tools/og-card/render.sh [out.png]     (default: public/og-card-2026.png)
#
# Runs on the host, not in Docker: it needs Google Chrome and network access,
# because card.html loads Instrument Sans and Source Serif 4 from Google Fonts,
# the same faces the site loads. It refuses to write the PNG if those fonts did
# not load, so a card is never published in fallback type.
#
# When the card changes, publish it under a NEW filename (Cloudflare caches the
# old one) and point the layout's default og:image at it; see README.md.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
OUT=${1:-"$ROOT/public/og-card-2026.png"}
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

CHROME=${CHROME:-}
if [ -z "$CHROME" ]; then
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" google-chrome chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then CHROME=$c; break; fi
  done
fi
[ -n "$CHROME" ] || { echo "render.sh: Chrome not found; set CHROME=/path/to/chrome" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
URL="file://$HERE/card.html"
FLAGS=(--headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1
       --window-size=1200,630 --virtual-time-budget=15000 --user-data-dir="$WORK/profile")

# 1. Did the real fonts load? card.html stamps body[data-fonts] once they settle.
"$CHROME" "${FLAGS[@]}" --dump-dom "$URL" 2>/dev/null > "$WORK/dom.html"
grep -q 'data-fonts="loaded"' "$WORK/dom.html" || {
  echo "render.sh: Instrument Sans / Source Serif 4 did not load (offline?); not writing $OUT" >&2; exit 1; }

# 2. The screenshot.
"$CHROME" "${FLAGS[@]}" --screenshot="$WORK/card.png" "$URL" >/dev/null 2>&1
[ -f "$WORK/card.png" ] || { echo "render.sh: Chrome produced no screenshot" >&2; exit 1; }

# 3. Exactly 1200x630, or nothing (the layout's og:image:width/height promise it).
SIZE=$(python3 -c 'import struct,sys; d=open(sys.argv[1],"rb").read(24); print("%dx%d" % struct.unpack(">II", d[16:24]))' "$WORK/card.png")
[ "$SIZE" = "1200x630" ] || { echo "render.sh: screenshot is $SIZE, expected 1200x630" >&2; exit 1; }

mkdir -p "$(dirname "$OUT")"
cp "$WORK/card.png" "$OUT"
echo "rendered $OUT ($SIZE)"
