#!/usr/bin/env bash
# Genera el PDF de un documento Markdown con el estilo del enunciado del curso.
# Requiere: pandoc >= 3, chromium (o google-chrome). La primera vez necesita
# Internet para descargar la fuente Arimo desde Google Fonts.
# Uso: tools/build-pdf.sh arquitectura/00-punto-de-partida.md
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$(realpath "${1:?uso: build-pdf.sh <archivo.md>}")"
SRC_DIR="$(dirname "$SRC")"
OUT_PDF="${SRC%.md}.pdf"
TMP_HTML="$(mktemp --suffix=.html -p "$SRC_DIR")"
trap 'rm -f "$TMP_HTML"' EXIT

TITLE="$(grep -m1 '^# ' "$SRC" | sed 's/^# //')"

pandoc "$SRC" \
  --from gfm \
  --to html5 \
  --standalone \
  --metadata pagetitle="$TITLE" \
  --css "$DOCS_DIR/tools/pdf-style.css" \
  --embed-resources \
  --resource-path "$SRC_DIR:$DOCS_DIR" \
  --output "$TMP_HTML"

BROWSER="$(command -v chromium-browser || command -v chromium || command -v google-chrome)"
"$BROWSER" --headless=new --disable-gpu --no-pdf-header-footer \
  --virtual-time-budget=10000 \
  --print-to-pdf="$OUT_PDF" "file://$TMP_HTML" 2>/dev/null

echo "PDF generado: $OUT_PDF"
