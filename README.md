# docs

Documentación del **Kit móvil de atención primaria en salud** (Plataformas I, 2026-2).

| Ruta | Contenido |
|---|---|
| `arquitectura/00-punto-de-partida.md` (+ `.pdf`) | Documento inicial: decisiones, supuestos, topología, plan IPv4/IPv6, DNS, flujos |
| `diagramas/` | Diagramas lógico y físico (PNG/SVG) y su especificación para Lucid (`*.lucid.json`) |
| `decisiones/` | Registros de decisiones (ADR) posteriores a v0.1 |
| `sustentacion/` | Material de la sustentación (E8) |
| `tools/` | Generación de PDF y diagramas |

Diagramas editables en Lucidchart:

- Lógico: <https://lucid.app/lucidchart/588a47ec-e999-4e1e-8f25-3931e7f353d8/edit>
- Físico: <https://lucid.app/lucidchart/6f4fcfbd-f4c1-4b09-b94e-0514d72603b5/edit>

## Generar el PDF

Requiere `pandoc` ≥ 3 y Chromium/Chrome:

```bash
./tools/build-pdf.sh arquitectura/00-punto-de-partida.md
```

## Regenerar los diagramas

Requiere `python3` y Chromium/Chrome:

```bash
./tools/build-diagrams.sh
```

El script ejecuta `tools/gen_lucid.py` (especificaciones `diagramas/diagrama-{logico,fisico}.lucid.json`), las convierte a SVG con `tools/render_diagram_svg.py` y genera el PNG que usa el PDF.

Si cambia la especificación, se debe volver a importar el JSON en Lucid (un documento nuevo por versión) para que ambos queden iguales.
