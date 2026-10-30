# P2 - DNS

## Qué se prueba

**Enunciado.** Se resuelve por nombre un servicio con registros A y AAAA y se accede sin escribir la IP. El enunciado (5.2) pide además demostrar conectividad extremo a extremo con ping, resolución DNS y acceso por IPv6.
**Presentación.** Los servicios responden por nombre en IPv4 e IPv6.

BIND9 en kit01 es autoritativo de `salud.movil` y recursivo para el kit, con la subzona `ad.salud.movil` delegada a Samba AD.

## Qué necesitas

Un equipo en la Interna (Clínica) con IPv6, o hacerlo desde kit01 o una VM en remoto. Para el extremo a extremo IPv6 se usa la Interna, porque F-22 permite el eco ICMP desde ahí.

## Paso a paso

1. Conectarse a `SaludMovil-Clinica` (o entrar a kit01 por NetBird).
2. Consultar A y AAAA de un servicio.
3. Hacer ping por nombre en IPv4 e IPv6.
4. Abrir el servicio por nombre en IPv4 e IPv6 con `curl`, y en el navegador sin escribir la IP.

## Con el script

Se ejecuta en un cliente de la Clínica, desde `docs/pruebas/`.

```bash
./scripts/P02-dns.sh
```

Compara los A y AAAA de diez servicios con lo esperado, revisa la bandera autoritativa, la consulta al DNS por IPv6, la delegación a Samba AD y las inversas (si hay `dig`), y hace ping y HTTP por nombre en las dos familias. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P02-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Comando | Qué muestra | Esperado |
|---|---|---|
| `dig +short A biblioteca.salud.movil` | El registro IPv4 del nombre | `10.20.20.12` |
| `dig +short AAAA biblioteca.salud.movil` | El registro IPv6 del nombre | `fd5a:fc7e:d716:20::12` |
| `dig A pacientes.salud.movil @10.20.20.10` | La respuesta completa del DNS del kit, con la bandera `aa` (autoritativa) | `10.20.20.11`, `flags: qr aa rd ra` |
| `dig AAAA pacientes.salud.movil @fd5a:fc7e:d716:20::10` | Lo mismo consultando el DNS por IPv6 | `fd5a:fc7e:d716:20::11` |
| `dig SRV _ldap._tcp.ad.salud.movil` | La delegación a Samba AD | `dc01.ad.salud.movil` |
| `dig -x 10.20.20.12 +short` y `dig -x fd5a:fc7e:d716:20::12 +short` | Las zonas inversas v4 y v6 | `comunidad01.salud.movil.` |
| `ping -4 -c3 biblioteca.salud.movil` | Que el nombre lleva al equipo por IPv4 | Respuestas de `10.20.20.12` |
| `ping -6 -c3 biblioteca.salud.movil` | Lo mismo por IPv6 | Respuestas de `fd5a:fc7e:d716:20::12` |
| `curl -4 -I http://biblioteca.salud.movil` y `curl -6 -I http://biblioteca.salud.movil` | Que el servicio responde por nombre en cada familia | `HTTP/1.1 200 OK` en las dos |

En Windows, `nslookup biblioteca.salud.movil` muestra las dos direcciones; `ping -4` y `ping -6` igual.

`dig` viene en `bind-utils` (Fedora) o `dnsutils` (Ubuntu). Sin `dig`, `getent ahosts biblioteca.salud.movil` muestra las direcciones que resuelve el sistema.

**En kit01.** `grep biblioteca /var/log/named/consultas.log | tail` muestra la consulta del cliente, con su IP de origen.

**macOS.** `dig` viene con el sistema, así que los mismos `dig` sirven. El ping IPv6 es `ping6 -c3 biblioteca.salud.movil`. Para ver lo que resuelve el sistema (con su caché), `dscacheutil -q host -a name biblioteca.salud.movil`.

## Si algo falla

- **El nombre da `127.0.0.1`.** Hay una línea en `/etc/hosts` del equipo. Comentarla.
- **`dig` responde pero `ping -6` no.** El equipo no tiene IPv6 global (ver P1).
- **`SERVFAIL` en `ad.salud.movil`.** Samba AD o el 53 de clinica01 (F-25). En clinica01, `systemctl status samba-ad-dc`.

## Evidencia

Salida de los `dig` A y AAAA, del `ping -4` y `ping -6` y de los dos `curl`. La línea de `consultas.log`.
