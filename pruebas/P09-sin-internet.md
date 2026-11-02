# P9 - Pérdida de Internet

## Qué se prueba

**Enunciado.** Se desconecta la salida externa y los servicios locales esenciales continúan disponibles.
**Presentación.** Se desconecta la WAN y todo sigue.

Todo lo esencial vive en el kit, como DNS (BIND9 autoritativo de `salud.movil`), NTP (Chrony en modo orphan), DHCP, el portal, DHIS2, SMB, la biblioteca, los videos y los formularios. Sin Internet solo falla lo que es de afuera.

## Qué necesitas

Estar en el sitio, con un celular en la Comunidad y un PC en la Clínica. **Al desconectar la WAN se cae NetBird**, así que quien esté en remoto pierde el acceso hasta reconectar. Es normal.

## Paso a paso

1. Con todo funcionando, avisar a quien esté en remoto.
2. Desconectar el cable de la **WAN** de kit01 (`enp170s0`, el que va a la red del laboratorio, **no** el que va a sw01).
3. Esperar 1 minuto.
4. Repetir desde los clientes las comprobaciones de la tabla.
5. Conectar un equipo nuevo a la Comunidad y ver que el portal aparece (P5 sin Internet).
6. Volver a conectar el cable de la WAN y esperar 2 minutos a que vuelva NetBird.

## Con el script

Se ejecuta en un cliente de la Comunidad o de la Clínica, con la WAN desconectada, desde `docs/pruebas/`.

```bash
./scripts/P09-sin-internet.sh
```

Revisa que lo externo falla, que los nombres del kit resuelven A y AAAA y que los servicios de esa red responden en IPv4 e IPv6 (en la Clínica también el 445 de `archivos`). Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P09-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

**Desde los clientes, con la WAN desconectada.**

| Dónde | Comando o acción | Qué muestra | Esperado |
|---|---|---|---|
| Clínica | `dig +short A pacientes.salud.movil` y `dig +short AAAA pacientes.salud.movil` | DNS local sin los forwarders | `10.20.20.11` y `fd5a:fc7e:d716:20::11` |
| Clínica | `dig +short google.com` | Que lo externo sí falla | Sin respuesta o `SERVFAIL` |
| Clínica | Abrir `https://pacientes.salud.movil` y buscar el paciente de P6 | DHIS2 sin Internet | Funciona |
| Clínica | Abrir `archivos` por SMB | SMB y Samba AD sin Internet | Funciona |
| Comunidad | `http://biblioteca.salud.movil`, `http://videos.salud.movil`, `https://registro.salud.movil` | Lo público local | Funciona |
| Comunidad | Equipo nuevo, `http://neverssl.com` | Que el portal sale sin Internet | Redirige al portal |
| Comunidad | Enviar un prerregistro | F-11 sin Internet | Muestra el código |

**En kit01 (por consola o al volver la WAN).**

| Comando | Qué muestra | Esperado |
|---|---|---|
| `ip link show enp170s0` | El enlace WAN durante la prueba | `NO-CARRIER`, `state DOWN` |
| `chronyc tracking` | NTP en modo orphan | `Stratum 10`, sigue sirviendo |
| `journalctl -u named --since -15min \| grep -i -E "forward\|timed out"` | Los forwarders sin respuesta, sin afectar lo local | Avisos de forwarders |
| `systemctl --failed` | Que nada falló | `0 loaded units listed` |
| En Grafana, **Estado del kit** | La disponibilidad durante el corte | Todo en verde salvo lo que depende de Internet |

**macOS.** El script y los `dig` y `curl` son iguales.

## Si algo falla

- **Un nombre del kit no resuelve sin Internet.** El equipo usa otro DNS (`resolvectl status`); debe usar `10.20.20.10`.
- **NetBird no vuelve.** Esperar 2-3 minutos; si no, revisar en el sitio que el cable quedó en `enp170s0`.

## Evidencia

Foto del cable desconectado, salida de los `dig` (los locales responden y `google.com` falla) y capturas de DHIS2, la biblioteca y el portal tomadas durante el corte, con la hora visible. `chronyc tracking` de kit01 en estrato 10.
