# Diagramas

La fuente editable de todos los diagramas está en Figma, en el archivo [Kit móvil de salud - Diagramas de los entregables](https://www.figma.com/design/iP6hzRKwsh2Nspko8DIvNU). La página **Diagramas** tiene un marco por diagrama, con el mismo nombre del PNG, y la página **Logos** tiene los logos oficiales de cada tecnología que usan los diagramas. Los textos usan Arimo, la misma fuente de los PDF.

| PNG | Marco en Figma | Dónde se usa |
|---|---|---|
| `diagrama-fisico.png` | `diagrama-fisico` | Documento de arquitectura (E1) |
| `diagrama-logico.png` | `diagrama-logico` | Documento de arquitectura (E1) |
| `flujos-firewall.png` | `flujos-firewall` | Matriz de seguridad (E4) |
| `despliegue-fases.png` | `despliegue-fases` | Guía de despliegue (E2) |
| `dependencias-arranque.png` | `dependencias-arranque` | Guía de despliegue (E2) |
| `encendido-apagado.png` | `encendido-apagado` | Guía de operación (E3) |
| `perfiles-mision.png` | `perfiles-mision` | Guía de operación (E3) |
| `flujo-respaldo.png` | `flujo-respaldo` | Plan de respaldo (E5) |
| `montaje-pruebas.png` | `montaje-pruebas` | Evidencias (E6) |
| `mapa-repositorios.png` | `mapa-repositorios` | Repositorio técnico (E7) |

## Exportar después de un cambio

Cada marco se exporta en PNG a escala 2x (3200 px de ancho) y reemplaza el archivo con el mismo nombre. En Figma, se selecciona el marco y en **Export** se elige `PNG` y `2x`. Después se regenera el PDF de los documentos que lo usan.
