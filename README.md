# docs

Documentación del **Kit móvil de atención primaria en salud** (Plataformas I, 2026-2).

| Ruta | Contenido |
|---|---|
| `arquitectura/00-punto-de-partida.md` (+ `.pdf`) | Documento inicial con decisiones, supuestos, topología, plan IPv4/IPv6, DNS y flujos |
| `diagramas/` | Diagramas lógico y físico, de flujos del firewall, del respaldo, del montaje de las pruebas, del encendido y apagado, de los perfiles por misión, de las fases del despliegue y de las dependencias al arrancar, con la fuente editable en draw.io (`*.drawio`) y el PNG que usan los PDF. Los logos son los oficiales de cada tecnología |
| `seguridad/` (+ `.pdf`) | Matriz de seguridad, con las reglas de firewall, los flujos, los puertos, la administración remota, las credenciales y la protección de las copias (E4) |
| `despliegue/` (+ `guia-despliegue.pdf`) | Guía de despliegue (E2). Preparación de la máquina de control, equipos de red, kit01, máquinas virtuales, orden de inicio, comprobación final y reconstrucción de una VM, con un índice en `README.md` |
| `operacion/` (+ `guia-operacion.pdf`) | Guía de operación (E3). Inicio y apagado, revisión rápida, usuarios, logs, actualización, operación sin Internet y cambio de perfil, con un índice en `README.md` |
| `respaldo/` (+ `.pdf`) | Plan de respaldo y restauración (E5) |
| `evidencias/` (+ `evidencias.pdf`) | Evidencias de las pruebas P1-P13 con su salida e interpretación, en un solo PDF (E6) |
| `decisiones/` | Registros de decisiones (ADR) posteriores a v0.1 |
| `pruebas/` | Guías de las pruebas de aceptación P1-P13, con un script por prueba (Linux y macOS) que guarda su salida como evidencia |
| `sustentacion/` | Material de la sustentación (E8) |
| `tools/` | Generación de PDF y diagramas |

## Generar el PDF

Cada entregable y el documento de arquitectura llevan su PDF al lado, con el mismo formato (logo, títulos, fuente y tablas de `tools/pdf-style.css`). Se regenera en el mismo PR que cambia el documento. Los entregables empiezan con el mismo encabezado que el documento de arquitectura.

Requiere `pandoc` ≥ 3 y Chromium/Chrome. Con varios archivos los junta en un solo PDF, cada uno desde una página nueva.

```bash
./tools/build-pdf.sh arquitectura/00-punto-de-partida.md
./tools/build-pdf.sh seguridad/matriz-seguridad.md
./tools/build-pdf.sh respaldo/plan-respaldo.md
./tools/build-pdf.sh -o evidencias/evidencias.pdf evidencias/README.md evidencias/P*.md
(cd despliegue && ../tools/build-pdf.sh -o guia-despliegue.pdf README.md preparacion.md red-fisica.md kit01.md maquinas-virtuales.md orden-de-inicio.md verificacion.md reconstruir-vm.md)
(cd operacion && ../tools/build-pdf.sh -o guia-operacion.pdf README.md inicio-y-apagado.md revision-rapida.md usuarios.md logs.md actualizacion.md sin-internet.md perfiles.md)
```

Los diagramas que van en una página horizontal propia se ponen con `<div class="diagrama"><img src="../diagramas/<nombre>.png"></div>`.

## Regenerar los diagramas

Los diagramas se editan en draw.io (escritorio o <https://app.diagrams.net>) abriendo `diagramas/*.drawio`. Para exportar los PNG se necesita draw.io Desktop (`drawio` en el PATH o el flatpak `com.jgraph.drawio.desktop`).

```bash
./tools/build-diagrams.sh
```
