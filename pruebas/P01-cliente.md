# P1 - Cliente comunitario

## Qué se prueba

**Enunciado.** El cliente obtiene IPv4, IPv6, DNS y gateway, y puede identificar su configuración.
**Presentación.** Un celular de la Comunidad recibe dirección, ruta y DNS.

El kit entrega IPv4 por Kea DHCPv4, IPv6 por SLAAC con el anuncio de radvd (prefijo `fd5a:fc7e:d716:40::/64`, gateway `fe80::1`) y el DNS IPv6 por DHCPv6 stateless (D-20).

## Qué necesitas

Un celular y, si se puede, un PC (Linux o Windows) que reciba IPv6 por Wi-Fi. La laptop de Melo no sirve para la parte IPv6: su tarjeta no recibe el multicast IPv6 del Wi-Fi (verificado con `tcpdump`, 0 paquetes ICMPv6).

## Paso a paso

1. Conectar el equipo a `SaludMovil-Comunidad` (abierta).
2. Aceptar el portal si aparece (P5).
3. Revisar la configuración con los comandos de abajo.
4. Hacer ping al gateway en IPv4 e IPv6 (F-23 lo permite).

## Con el script

Se ejecuta en el cliente conectado al Wi-Fi del kit, desde `docs/pruebas/`.

```bash
./scripts/P01-cliente.sh
```

Revisa IPv4, IPv6, gateway y DNS contra lo esperado para la red en la que está, hace ping al gateway en las dos familias y avisa si `/etc/hosts` tiene nombres del kit. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P01-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

**Celular (iPhone).** Ajustes → Wi-Fi → (i) junto a la red.

| Dónde mirar | Qué debe decir |
|---|---|
| Dirección IP | `10.20.40.1xx` |
| Router | `10.20.40.1` |
| DNS (Configurar DNS) | `10.20.20.10` y `fd5a:fc7e:d716:20::10` |
| Dirección IPv6 | Una o más que empiezan con `fd5a:fc7e:d716:40:` |

**Linux.**

| Comando | Qué muestra | Esperado |
|---|---|---|
| `ip -4 addr show <wifi>` | La dirección IPv4 que dio Kea | `inet 10.20.40.1xx/24` |
| `ip -6 addr show <wifi>` | Direcciones IPv6. `scope global` es la de SLAAC; `fe80::` es la link-local, que siempre existe | Una `fd5a:fc7e:d716:40:.../64 scope global` |
| `ip route` | La ruta por defecto IPv4 | `default via 10.20.40.1` |
| `ip -6 route` | La ruta por defecto IPv6, aprendida del anuncio del router | `default via fe80::1` |
| `resolvectl status <wifi>` | Los DNS que recibió | `10.20.20.10` y `fd5a:fc7e:d716:20::10` |
| `ping -c3 10.20.40.1` | Que el gateway responde en IPv4 | 3 respuestas |
| `ping -6 -c3 fe80::1%<wifi>` | Que el gateway responde en IPv6 (link-local, por eso va `%<wifi>`) | 3 respuestas |

**Windows.** `ipconfig /all` muestra en el adaptador Wi-Fi la dirección IPv4, las IPv6 (`fd5a:...`), la puerta de enlace (`10.20.40.1` y `fe80::1%n`) y los servidores DNS. Después `ping 10.20.40.1` y `ping -6 fe80::1%n` (n es el número de interfaz que muestra `ipconfig`).

**En kit01 (remoto).** Confirma lo que el cliente recibió.

| Comando | Qué muestra |
|---|---|
| `grep <MAC> /var/lib/kea/kea-leases4.csv \| tail -1` | El préstamo IPv4 que dio Kea, con la MAC y el nombre del equipo |
| `ip -6 neigh show dev br-com` | Las IPv6 de los clientes que kit01 ya conoce |
| `tail /var/log/kitsalud/kit01/dhcp.log` | Los `DHCP4_LEASE_ALLOC` del cliente |

**macOS.** Ajustes del Sistema → Wi-Fi → Detalles de la red → TCP/IP y DNS. En la terminal, `ipconfig getifaddr en0` (IPv4), `ifconfig en0 | grep inet6` (IPv6), `netstat -rn -f inet | grep default` y `netstat -rn -f inet6 | grep default` (gateways), `scutil --dns | grep nameserver` (DNS), `ping -c3 10.20.40.1` y `ping6 -c3 fe80::1%en0`. `en0` suele ser el Wi-Fi; `route -n get default` lo confirma.

## Si algo falla

- **Sin IPv4 o "no internet connection".** Revisar en sw01 que la VLAN 40 incluya a `bridge-kit` (`/interface bridge vlan print`). Sin eso, las respuestas de kit01 no llegan al AP (corregido el 2026-10-30, rama `fix/11-vlan40-cpu`).
- **Sin IPv6 en un PC Linux con Docker o libvirt.** Con `net.ipv6.conf.all.forwarding=1` el sistema se comporta como router e ignora los anuncios. Probar con `sudo sysctl -w net.ipv6.conf.all.forwarding=0` y reconectar.
- **IPv6 en el celular sí y en el PC no.** Comprobar si llegan los anuncios con `sudo timeout 20 tcpdump -ni <wifi> icmp6`. Si no llega nada, es la tarjeta o su driver.

## Evidencia

Captura de la pantalla del celular con IPv4, router, DNS e IPv6, o la salida de `ip -4 addr`, `ip -6 addr`, `ip route`, `ip -6 route` y `resolvectl status` de un PC. La línea del préstamo en `kea-leases4.csv`.
