#!/usr/bin/env bash
# Regenera los diagramas lógico y físico: especificación Lucid (JSON), SVG y PNG.
# Requiere: python3, chromium (o google-chrome).
# Uso: tools/build-diagrams.sh
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DOCS_DIR"

python3 tools/gen_lucid.py

BROWSER="$(command -v chromium-browser || command -v chromium || command -v google-chrome)"
for d in logico fisico; do
  base="diagramas/diagrama-$d"
  python3 tools/render_diagram_svg.py "$base.lucid.json" "$base.svg"
  size="$(grep -o -m1 'width="[0-9]*" height="[0-9]*"' "$base.svg" | tr -dc '0-9 ' | tr ' ' ',' | sed 's/,,*/,/g;s/^,//;s/,$//')"
  "$BROWSER" --headless=new --hide-scrollbars --window-size="$size" \
    --screenshot="$DOCS_DIR/$base.png" "file://$DOCS_DIR/$base.svg" 2>/dev/null
  echo "Diagrama generado: $base.png ($size)"
done
