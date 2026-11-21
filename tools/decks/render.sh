#!/bin/bash
# Render a deck to slide PNGs, 1600 px wide, for QA and for the site.
#
#   tools/decks/render.sh <package_dir>
#
# Reads <package_dir>/<slug>.pptx (slug = the folder name) and writes
# <package_dir>/slides/slide-NN.png. Uses the kit's fontconfig so the
# Keynote fonts are substituted by open ones with matching spacing, and a
# throwaway LibreOffice profile so a running LibreOffice cannot interfere.
set -euo pipefail
KIT=$(cd "$(dirname "$0")" && pwd)
P=$(cd "$1" && pwd)
S=$(basename "$P")
[ -f "$P/$S.pptx" ] || { echo "render.sh: $P/$S.pptx not found" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export FONTCONFIG_FILE="$KIT/fonts/fonts.conf"
mkdir -p "$P/slides"
rm -f "$P"/slides/slide-*.png
timeout 300 soffice -env:UserInstallation="file://$WORK/profile" --headless --convert-to pdf \
  --outdir "$WORK" "$P/$S.pptx" >/dev/null 2>&1
[ -f "$WORK/$S.pdf" ] || { echo "render.sh: LibreOffice produced no PDF" >&2; exit 1; }
timeout 300 pdftoppm -png -scale-to-x 1600 -scale-to-y -1 "$WORK/$S.pdf" "$WORK/s"
i=0
for f in $(ls "$WORK"/s-*.png | sort); do
  i=$((i + 1))
  cp "$f" "$(printf '%s/slides/slide-%02d.png' "$P" "$i")"
done
echo "rendered $i slides into $P/slides"
