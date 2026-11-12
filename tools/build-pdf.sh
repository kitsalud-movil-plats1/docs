#!/usr/bin/env bash
# Genera el PDF de uno o varios documentos Markdown con el estilo del enunciado
# del curso. Con varios archivos los junta en un solo PDF, cada uno desde una
# página nueva, y los enlaces entre ellos pasan a ser enlaces dentro del PDF.
# Requiere: pandoc >= 3, chromium (o google-chrome). La primera vez necesita
# Internet para descargar la fuente Arimo desde Google Fonts.
# Uso: tools/build-pdf.sh [-o salida.pdf] archivo.md [archivo.md...]
#   tools/build-pdf.sh arquitectura/documento-arquitectura.md
#   tools/build-pdf.sh -o evidencias/evidencias.pdf evidencias/README.md evidencias/P*.md
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT_PDF=""
# Ruta absoluta sin exigir que el archivo exista (realpath -m no existe en macOS)
absoluta() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
if [ "${1:-}" = -o ]; then OUT_PDF="$(absoluta "$2")"; shift 2; fi
[ $# -ge 1 ] || { echo "uso: build-pdf.sh [-o salida.pdf] archivo.md [archivo.md...]" >&2; exit 2; }

FUENTES=()
for f in "$@"; do FUENTES+=("$(absoluta "$f")"); done
PRIMERO="${FUENTES[0]}"
SRC_DIR="$(dirname "$PRIMERO")"
[ -n "$OUT_PDF" ] || OUT_PDF="${PRIMERO%.md}.pdf"

TMP_DIR="$(mktemp -d)"
TMP_HTML="$SRC_DIR/.pdf-$$.html"
trap 'rm -rf "$TMP_DIR" "$TMP_HTML"' EXIT

# Cada archivo después del primero empieza en una página nueva, con un ancla
# que lleva su nombre para que los enlaces del índice apunten a él
ENTRADAS=("$PRIMERO")
RUTAS="$SRC_DIR"
for f in "${FUENTES[@]:1}"; do
  salto="$TMP_DIR/salto-$(basename "$f")"
  printf '\n<div class="salto" id="%s"></div>\n\n' "$(basename "$f")" > "$salto"
  ENTRADAS+=("$salto" "$f")
  RUTAS="$RUTAS:$(dirname "$f")"
done

cat > "$TMP_DIR/enlaces.lua" <<'FIN'
-- Los enlaces a archivos .md que van en el mismo PDF pasan a su ancla
local incluidos = {}
for nombre in string.gmatch(os.getenv("PDF_INCLUIDOS") or "", "[^:]+") do incluidos[nombre] = true end
function Link(el)
  if incluidos[el.target] then el.target = "#" .. el.target end
  return el
end
FIN
INCLUIDOS=""
for f in "${FUENTES[@]:1}"; do INCLUIDOS="$INCLUIDOS:$(basename "$f")"; done

TITLE="$(grep -m1 '^# ' "$PRIMERO" | sed 's/^# //')"

PDF_INCLUIDOS="$INCLUIDOS" pandoc "${ENTRADAS[@]}" \
  --from gfm \
  --to html5 \
  --standalone \
  --metadata pagetitle="$TITLE" \
  --css "$DOCS_DIR/tools/pdf-style.css" \
  --lua-filter "$TMP_DIR/enlaces.lua" \
  --embed-resources \
  --resource-path "$RUTAS:$DOCS_DIR" \
  --output "$TMP_HTML"

MAC_CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BROWSER="$(command -v chromium-browser || command -v chromium || command -v google-chrome || { [ -x "$MAC_CHROME" ] && echo "$MAC_CHROME"; })"
"$BROWSER" --headless=new --disable-gpu --no-pdf-header-footer \
  --virtual-time-budget=10000 \
  --print-to-pdf="$OUT_PDF" "file://$TMP_HTML" 2>/dev/null

echo "PDF generado: $OUT_PDF"
