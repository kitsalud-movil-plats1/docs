# P8 - Tiempo

## Qué se prueba

**Enunciado.** Dos o más nodos muestran sincronización con el servicio NTP interno.
**Presentación.** Todos los equipos toman la hora de kit01.

Chrony en kit01 (`ntp.salud.movil`, `10.20.20.10` y `fd5a:fc7e:d716:20::10`) toma la hora del pool cuando hay Internet y sigue sirviendo con `local stratum 10 orphan` cuando no hay. clinica01, comunidad01 y sw01 son clientes. Una hora coherente importa para Kerberos (máximo 5 min de diferencia), los logs y los certificados.

## Qué necesitas

SSH a kit01 por NetBird y, si se puede, una estación de la Interna.

## Paso a paso

1. En kit01, ver sus fuentes y los clientes que le piden la hora.
2. En clinica01 y comunidad01, ver que su fuente es kit01.
3. En sw01, ver el estado del cliente NTP.
4. Opcional, consultar `ntp.salud.movil` desde una estación de la Interna sin cambiar su hora.
5. Con P9, repetir sin Internet.

## Con el script

Se ejecuta en la máquina de control (Ansible del kit, por NetBird), desde `docs/pruebas/`.

```bash
./scripts/P08-tiempo.sh [--estacion]
```

Revisa `chronyc tracking` y los clientes en kit01, y que clinica01 y comunidad01 tienen a kit01 como fuente elegida, con su desfase. Con `--estacion` mide además el desfase de este equipo contra `ntp.salud.movil` sin cambiar su hora. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P08-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Dónde | Comando | Qué muestra | Esperado |
|---|---|---|---|
| kit01 | `chronyc tracking` | Estado de kit01: fuente, estrato y desfase | `Leap status: Normal`, estrato 2-4 con Internet; estrato 10 sin Internet |
| kit01 | `chronyc sources -v` | Las fuentes del pool; `^*` es la elegida | Una fuente con `^*` |
| kit01 | `sudo chronyc clients` | Los equipos que le piden la hora, por nombre inverso o IP | `dc01.ad.salud.movil` (clinica01), `fd5a:fc7e:d716:20::12` (comunidad01), `10.20.10.2` (sw01) y los clientes |
| clinica01 | `chronyc sources` | Su única fuente | `^* ntp.salud.movil` (o `10.20.20.10`) |
| clinica01 | `chronyc tracking` | Su desfase con kit01 | `System time` de milisegundos o menos |
| comunidad01 | `chronyc sources` y `chronyc tracking` | Lo mismo | Igual que clinica01 |
| sw01 | `/system ntp client print` y `/system clock print` | Cliente activo y la hora | `status: synchronized`, servidor `10.20.20.10` |
| Estación Linux | `chronyd -Q "server ntp.salud.movil iburst"` (con sudo) | El desfase de la estación contra kit01, sin cambiar la hora | Una línea con el desfase |
| Estación Windows | `w32tm /stripchart /computer:ntp.salud.movil /samples:3` | Lo mismo en Windows | Tres muestras con el desfase |

En `chronyc sources`, `^` es un servidor, `*` es el que se está usando y `+` uno aceptable. `Reach 377` indica que respondieron las últimas 8 consultas.

**macOS.** `sntp ntp.salud.movil` muestra el desfase contra kit01 sin cambiar la hora y sin sudo (es lo que usa el script con `--estacion`).

## Si algo falla

- **El cliente muestra `^?`.** No llega al 123/udp de kit01. Revisar F-03.
- **kit01 en estrato 10 con Internet.** No llega al pool. Revisar F-18 y `chronyc sources`.

## Evidencia

Salida de `chronyc tracking` y `chronyc sources` en kit01, clinica01 y comunidad01, de `chronyc clients` en kit01 y de `/system ntp client print` en sw01. La misma de kit01 durante P9.
