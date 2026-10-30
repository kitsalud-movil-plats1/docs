# P10 - Firewall IPv6

## Qué se prueba

**Enunciado.** Se realizan una prueba de acceso permitido y otra de acceso bloqueado mediante IPv6.
**Presentación.** Por IPv6 se llega a comunidad01 y no a clinica01.

Los dos destinos están en la misma red (`fd5a:fc7e:d716:20::/64`), así que el resultado muestra que la regla es por equipo y por puerto, con la misma política que IPv4 (F-09 permite, F-20 bloquea y registra).

## Qué necesitas

Un cliente de la Comunidad **con IPv6 global** y el portal aceptado. La laptop de Melo no recibe IPv6 por Wi-Fi; usar otro PC, o `prueba01`, la VM de la Comunidad que hace de celular (D-24).

## Paso a paso

1. Comprobar que el cliente tiene `fd5a:fc7e:d716:40:...` (P1).
2. Aceptar el portal.
3. Hacer las dos pruebas por IPv6 forzado.
4. Hacer las mismas por IPv4 para comparar.
5. Revisar en kit01 el bloqueo registrado.

## Con el script

Se ejecuta en un cliente de la Comunidad con IPv6 global y el portal aceptado, desde `docs/pruebas/`.

```bash
./scripts/P10-firewall-ipv6.sh
```

Por IPv6 y luego por IPv4, revisa que biblioteca y registro responden y que DHIS2, clinica01 por IP directa y el SSH de kit01 quedan bloqueados. Si el equipo no tiene IPv6 global, se detiene y lo dice. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P10-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Comando | Qué prueba | Esperado |
|---|---|---|
| `curl -6 -I http://biblioteca.salud.movil` | Permitido, comunidad01 por IPv6 (F-09) | `200 OK` |
| `curl -6 -I https://registro.salud.movil` | Permitido, comunidad01 443 por IPv6 | `200 OK` |
| `curl -6 -k -m 5 -I https://pacientes.salud.movil` | Bloqueado, clinica01 por IPv6 (F-20) | Timeout |
| `curl -6 -m 5 -I "http://[fd5a:fc7e:d716:20::11]/"` | Bloqueado, clinica01 por IP directa | Timeout |
| `nc -6 -vz -w 5 fd5a:fc7e:d716:20::10 22` | Bloqueado, SSH de kit01 | Timeout |
| `curl -4 -I http://biblioteca.salud.movil` y `curl -4 -k -m 5 -I https://pacientes.salud.movil` | Lo mismo en IPv4 | `200` y timeout |

`-6` obliga a curl a usar la dirección AAAA, así que lo que se prueba es la política IPv6 y no un respaldo por IPv4.

**En kit01 (remoto).**

| Comando | Qué muestra |
|---|---|
| `grep "SRC=fd5a:fc7e:d716:0040" /var/log/kitsalud/kit01/firewall.log \| tail` | Los bloqueos IPv6 con `fw-drop F-20`, destino `fd5a:fc7e:d716:0020:...:0011` y puerto |
| `sudo nft list chain inet filtro bloqueo_f20` | El contador que sube |

**Con prueba01, en remoto.** `ansible-playbook playbooks/verificar-flujos.yml` (desde `platform/ansible`) enciende prueba01, prueba cada flujo de la matriz en IPv4 e IPv6 y muestra un resumen con los bloqueos registrados.

**macOS.** Los `curl -6` son iguales; el SSH con `nc -6 -z -G 5 -w 5 fd5a:fc7e:d716:20::10 22`.

## Si algo falla

- **`curl -6` falla enseguida en todo.** El cliente no tiene IPv6 global (P1).
- **`pacientes` abre por IPv6.** Revisar la cadena `forward` de `inet filtro` en kit01 (`sudo nft list chain inet filtro forward`).

## Evidencia

Salida de los `curl -6` permitidos y bloqueados, la misma en IPv4 y las líneas `fw-drop F-20` con el origen `fd5a:fc7e:d716:40:...`.
