# docs

Documentación del **Kit móvil de atención primaria en salud** (Plataformas I, 2026-2).

| Ruta | Contenido |
|---|---|
| `arquitectura/00-punto-de-partida.md` (+ `.pdf`) | Documento inicial: decisiones, supuestos, topología, plan IPv4/IPv6, DNS, flujos |
| `diagramas/` | Diagramas lógico y físico: fuente editable en draw.io (`*.drawio`) y PNG que usa el PDF |
| `decisiones/` | Registros de decisiones (ADR) posteriores a v0.1 |
| `sustentacion/` | Material de la sustentación (E8) |
| `tools/` | Generación de PDF y diagramas |

## Generar el PDF

Requiere `pandoc` ≥ 3 y Chromium/Chrome:

```bash
./tools/build-pdf.sh arquitectura/00-punto-de-partida.md
```

## Regenerar los diagramas

Los diagramas se editan en draw.io (escritorio o <https://app.diagrams.net>) abriendo `diagramas/*.drawio`. Para exportar los PNG se necesita draw.io Desktop (`drawio` en el PATH o el flatpak `com.jgraph.drawio.desktop`):

```bash
./tools/build-diagrams.sh
```
