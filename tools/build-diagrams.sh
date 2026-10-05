#!/usr/bin/env bash
# Exporta los diagramas draw.io (diagramas/*.drawio) a PNG para el documento.
# Requiere draw.io Desktop: `drawio` en el PATH o el flatpak com.jgraph.drawio.desktop.
# Uso: tools/build-diagrams.sh
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DOCS_DIR"

if command -v drawio >/dev/null; then
  DRAWIO=(drawio)
else
  DRAWIO=(flatpak run com.jgraph.drawio.desktop)
fi

for src in diagramas/*.drawio; do
  out="${src%.drawio}.png"
  "${DRAWIO[@]}" -x -f png -s 2 -b 20 -o "$out" "$src" 2>/dev/null
  echo "Diagrama generado: $out"
done
