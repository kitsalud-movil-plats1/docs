# P3 - Aislamiento

## Qué se prueba

**Enunciado.** Un cliente de invitados intenta acceder a un servicio clínico o de administración y la conexión queda bloqueada.
**Presentación.** La Comunidad no llega a pacientes ni a SSH.

F-20 bloquea y registra todo lo que va de la Comunidad a la Interna, a clinica01 y a la gestión de kit01 (22 y `monitoreo`). El AP aísla además a los clientes entre sí (AP Isolation).

## Qué necesitas

Un PC (o celular con navegador) en `SaludMovil-Comunidad`, con el portal aceptado, para que se vea que el bloqueo no depende del portal.

## Paso a paso

1. Conectarse a la Comunidad y aceptar el portal.
2. Intentar abrir los servicios clínicos y de administración.
3. Revisar en kit01 que los intentos quedaron registrados.

## Con el script

Se ejecuta en un cliente de la Comunidad con el portal aceptado, desde `docs/pruebas/`.

```bash
./scripts/P03-aislamiento.sh [IP de otro cliente]
```

Intenta DHIS2, la consulta de prerregistros, SMB, Grafana y el SSH de kit01 en IPv4 e IPv6 y espera que todo quede bloqueado; con la IP de otro cliente revisa el aislamiento del AP. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P03-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

**En el cliente.**

| Comando | Qué intenta | Esperado |
|---|---|---|
| `curl -4 -k -m 5 https://pacientes.salud.movil` | DHIS2 en clinica01 por IPv4 | `Connection timed out` (bloqueado) |
| `curl -6 -k -m 5 https://pacientes.salud.movil` | Lo mismo por IPv6 | Sin respuesta (bloqueado) |
| `nc -vz -w 5 10.20.20.10 22` y `nc -vz -w 5 fd5a:fc7e:d716:20::10 22` | SSH de kit01 | Timeout |
| `nc -vz -w 5 10.20.40.1 22` | SSH de kit01 por su IP en la Comunidad | Timeout |
| `curl -k -m 5 https://monitoreo.salud.movil` | Grafana | Timeout |
| `nc -vz -w 5 10.20.20.11 445` | SMB de clinica01 | Timeout |
| `ping -c3 10.20.10.1` | La Interna | Sin respuesta |
| `ping -c3 <IP de otro celular en la Comunidad>` | Otro cliente del mismo SSID | Sin respuesta (AP Isolation) |

`curl -k` ignora el certificado, así que el único motivo para que falle es la red. `nc -vz` solo intenta abrir la conexión TCP sin enviar nada. `-m 5` y `-w 5` cortan a los 5 s.

En el celular, abrir `https://pacientes.salud.movil` no carga.

**En kit01 (remoto).**

| Comando | Qué muestra |
|---|---|
| `grep "SRC=10.20.40.1xx" /var/log/kitsalud/kit01/firewall.log \| tail` | Cada intento bloqueado, con el prefijo `fw-drop F-20`, origen, destino y puerto |
| `grep "SRC=fd5a:fc7e:d716:0040" /var/log/kitsalud/kit01/firewall.log \| tail` | Los intentos por IPv6 (el log escribe la dirección completa, con los ceros) |
| `sudo nft list chain inet filtro bloqueo_f20` | El contador de la regla, que sube con cada intento |

**macOS.** Los `curl` son iguales. `nc` es el de BSD: `nc -z -G 5 -w 5 10.20.20.10 22` y `nc -6 -z -G 5 -w 5 fd5a:fc7e:d716:20::10 22` (`-G` es el tiempo para conectar).

## Si algo falla

- **`pacientes` abre desde la Comunidad.** Revisar que el equipo esté de verdad en la Comunidad (`10.20.40.x`) y la cadena `bloqueo_f20` en kit01.
- **El ping entre clientes responde.** Confirmar en el AP, Wireless → Wireless Advanced, que **Enable AP Isolation** esté marcado y guardado.

## Evidencia

Salida de los `curl` y `nc` en IPv4 e IPv6, y las líneas `fw-drop F-20` correspondientes en `firewall.log`.
