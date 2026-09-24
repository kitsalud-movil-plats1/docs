# docs

Documentación del **Kit móvil de atención primaria en salud** (Plataformas I, 2026-2).

| Ruta | Contenido |
|---|---|
| `arquitectura/00-punto-de-partida.md` (+ `.pdf`) | Documento inicial: decisiones, supuestos, topología, plan IPv4/IPv6, DNS, flujos |
| `diagramas/` | Diagrama lógico (PNG/SVG) y su especificación para Lucid (`*.lucid.json`) |
| `decisiones/` | Registros de decisiones (ADR) posteriores a v0.1 |
| `sustentacion/` | Material de la sustentación (E8) |
| `tools/` | Generación de PDF y diagramas |

Diagrama editable en Lucidchart: <https://lucid.app/lucidchart/6bf45f05-e5a8-42cb-a7af-6a79dc097531/edit>

## Generar el PDF

Requiere `pandoc` ≥ 3 y Chromium/Chrome:

```bash
./tools/build-pdf.sh arquitectura/00-punto-de-partida.md
```

## Regenerar el diagrama

```bash
python3 tools/gen_lucid.py                     # actualiza diagramas/diagrama-logico.lucid.json
python3 tools/render_diagram_svg.py diagramas/diagrama-logico.lucid.json diagramas/diagrama-logico.svg
chromium-browser --headless=new --hide-scrollbars --window-size=2100,1590 \
  --screenshot="$PWD/diagramas/diagrama-logico.png" "file://$PWD/diagramas/diagrama-logico.svg"
```

Si cambia la especificación, se debe volver a importar el JSON en Lucid para que ambos queden iguales.
