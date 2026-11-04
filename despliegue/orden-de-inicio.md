# Orden de inicio

Esta parte explica qué arranca primero cuando se enciende el kit y de qué depende cada servicio. Al encender no hay que hacer nada a mano. El orden lo resuelven systemd en cada equipo, el arranque automático de libvirt para las VMs y los reintentos de las propias aplicaciones.

PENDIENTE diagrama de dependencias

## Secuencia al encender

| Fase | Equipo | Qué arranca, en orden | Tiempo medido |
|---|---|---|---|
| 1 | sw01 y ap01 | El switch carga su configuración y levanta las VLAN. El AP levanta sus dos Wi-Fi | Hasta que se encienden los indicadores de sus puertos |
| 2 | kit01, sistema | Se monta el volumen de las VMs (`/var/lib/libvirt/images`, con `nofail`). nftables carga el firewall antes de que exista la red (`Before=network-pre.target`), así nunca hay un momento sin filtro. Después systemd-networkd crea la WAN, las VLAN, los bridges y sus direcciones | 2 min 15 s en su último arranque, casi todo esperando la red |
| 3 | kit01, servicios de red | BIND9, Chrony, Kea DHCPv4 y DHCPv6 (después de la red y de la hora), radvd, rsyslog, nginx, el portal cautivo (después de nftables, porque escribe en su set) y NetBird | Segundos después de la red |
| 4 | kit01, UPS y monitoreo | `kit-ups-inicial` deja la UPS lógica en `OL` antes de que arranque su driver, y después `nut-server` y `nut-monitor`. Prometheus, blackbox y Grafana empiezan a probar los servicios | Segundos |
| 5 | kit01, VMs | libvirtd enciende clinica01 y comunidad01 a la vez, porque las dos tienen arranque automático. prueba01 queda apagada | Las VMs arrancan su sistema en unos 7 s |
| 6 | clinica01 | ufw, la red, Chrony y rsyslog. Después Samba AD y Docker (los dos esperan `network-online.target`). En Docker, PostgreSQL primero y DHIS2 cuando la base pasa su healthcheck. La consulta de prerregistros y Caddy arrancan a la vez y reintentan hasta que responden el dominio y la base | DHIS2 tarda unos 25 s con datos |
| 7 | comunidad01 | ufw, la red, Chrony y rsyslog. Después Docker con Kiwix, Jellyfin, el formulario y Caddy. El formulario reintenta hasta que responde PostgreSQL de clinica01 | Segundos |
| 8 | Todo el kit | Prometheus ve todas las sondas en verde | 42 s después de encender las VMs |

Las dos VMs arrancan juntas porque libvirt no tiene un retardo entre ellas, y no hace falta. Ninguna aplicación de comunidad01 deja de arrancar si clinica01 todavía no responde, solo reintenta. Lo mismo pasa con Grafana en kit01, que deja entrar con su cuenta local mientras el dominio no responde.

## Dependencias de cada servicio

| Servicio | Necesita | Si falta |
|---|---|---|
| Firewall (nftables, kit01) | Nada | Es lo primero que se carga. Con un error en el archivo, kit01 arranca sin las tablas del kit y NetBird sigue entrando |
| DNS (BIND9, kit01) | Las direcciones `10.20.20.10` y `fd5a:fc7e:d716:20::10` de `br-srv` | Responde en cuanto aparecen las direcciones. Los nombres de `ad.salud.movil` los delega a Samba en clinica01 |
| Hora (Chrony, kit01) | La red. Internet es opcional | Sin Internet sigue dando la hora local del kit a todos los equipos |
| DHCP y anuncios IPv6 (Kea y radvd, kit01) | `lan0.10` y `br-com` | Los clientes no reciben dirección hasta que arrancan |
| Portal cautivo (kit01) | nftables, por su set `portal_ok`, y nginx | La Comunidad no puede aceptar las condiciones y no pasa del portal |
| Dominio (Samba AD, clinica01) | La hora de kit01 (Kerberos falla con más de 5 minutos de diferencia) y su propio DNS | No entran la consulta de prerregistros, los recursos SMB ni los usuarios del dominio en Grafana |
| PostgreSQL (clinica01) | El disco de datos en `/srv` | DHIS2 espera su healthcheck. El formulario y la consulta reintentan |
| DHIS2 (clinica01) | PostgreSQL sano | No arranca hasta que la base está lista |
| Consulta de prerregistros (clinica01) | PostgreSQL y el dominio por LDAPS | Responde con error hasta que los dos están |
| Formulario de prerregistro (comunidad01) | PostgreSQL de clinica01 | Avisa al usuario y se recupera solo cuando vuelve la base |
| Biblioteca y videos (comunidad01) | El disco de datos en `/srv` | Funcionan aunque clinica01 esté apagada |
| Publicación de contenido (clinica01) | Samba (el recurso `contenido`) y el SSH de comunidad01 | La pasada falla y la siguiente, 10 minutos después, lo intenta de nuevo |
| Logs centrales (rsyslog, kit01) | Las direcciones de `br-srv` | Las VMs guardan los mensajes en una cola en disco y los entregan cuando vuelve |
| Copias (restic, kit01) | Las VMs encendidas y el disco USB | La copia de esa semana queda marcada como fallida en el monitoreo |
| Grafana (kit01) | nginx y, para los usuarios del dominio, Samba | Queda la cuenta local `admin` |

## Cómo comprobar el orden

```bash
# En kit01
systemd-analyze critical-chain multi-user.target    # qué esperó a qué en el último arranque
systemctl list-dependencies --after kitsalud-portal # el portal después de nftables
virsh -c qemu:///system list --autostart            # clinica01 y comunidad01
# En una VM (por ejemplo, desde kit01, ssh kitsalud@10.20.20.11)
systemd-analyze critical-chain docker.service       # Docker después de network-online.target
sudo docker compose -f /srv/dhis2/compose.yml ps    # db (healthy) antes que core
```

**Medido el 2026-11-04.** clinica01 llegó a `multi-user.target` en 7,6 s y comunidad01 en 6,6 s, en los dos casos con Docker esperando `network-online.target`. En el simulacro de corte de energía de ese día, todo volvió a verde 42 s después de encender las VMs.
