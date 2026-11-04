# Revisión de logs

Este procedimiento explica dónde quedan los registros del kit y cómo encontrar en ellos los eventos que más se consultan. Todos los equipos envían sus logs a kit01, así que casi todo se revisa desde ahí, aunque una máquina virtual esté apagada.

## Lo que se necesita

- Acceso a kit01 por SSH (`ssh <usuario>@10.20.10.1` desde la red Interna o `ssh <usuario>@100.90.225.113` por NetBird).
- `sudo`, porque los archivos son del grupo `adm`.

## Dónde está cada log

En kit01, una carpeta por equipo en `/var/log/kitsalud/`. El equipo se decide por la dirección de origen, así que un equipo no puede escribir en la carpeta de otro.

| Archivo | Qué tiene |
|---|---|
| `/var/log/kitsalud/<equipo>/auth.log` | Inicios de sesión SSH, `sudo` y accesos rechazados de `kit01`, `clinica01` y `comunidad01`. En clinica01 además los inicios de sesión del dominio, con la etiqueta `samba-auth` |
| `/var/log/kitsalud/<equipo>/syslog.log` | Todo lo demás de cada equipo, incluido `sw01` (entradas al switch, cambios de configuración y enlaces) |
| `/var/log/kitsalud/kit01/firewall.log` | Lo que bloqueó el firewall, con la etiqueta `fw-drop` |
| `/var/log/kitsalud/kit01/dhcp.log` | Direcciones entregadas por el DHCP de IPv4 y los mensajes del DHCP de IPv6 |
| `/var/log/kitsalud/kit01/dns.log` | Mensajes generales del DNS (arranque, recargas, errores de zona) |
| `/var/log/named/consultas.log` | Cada consulta al DNS del kit, con el equipo que preguntó |

El punto de acceso (ap01) no envía sus logs. Su registro se ve en su página de administración, en **System Tools**, **System Log**.

Los servicios de cada equipo también quedan en su journal (`journalctl`), y las aplicaciones de las máquinas virtuales en los logs de Docker.

## Eventos comunes

Los comandos se ejecutan en kit01. Para seguir un archivo mientras se reproduce un problema se usa `sudo tail -f <archivo>`.

### Inicios de sesión fallidos por SSH

```bash
sudo grep -h -E "Failed password|Invalid user" /var/log/kitsalud/*/auth.log | tail
```

```
2026-11-02T18:38:50.087100-05:00 comunidad01 sshd[10249]: Failed password for kitsalud from 10.20.20.1 port 41780 ssh2
```

Cada línea trae la hora, el equipo, el usuario y la dirección de origen. `Invalid user` es un usuario que no existe. Muchos intentos seguidos desde una dirección que no es de administración son para revisar.

### Uso de `sudo`

```bash
sudo grep -h "sudo:.*COMMAND=" /var/log/kitsalud/*/auth.log | tail
```

```
2026-11-02T18:22:39.623127-05:00 comunidad01 sudo:   backup : PWD=/var/backups ; USER=root ; COMMAND=/usr/local/sbin/backup-extraer
```

El usuario `backup` es el de las copias semanales y solo ejecuta el comando de extracción. Las demás líneas son del usuario de administración.

### Inicios de sesión del dominio

```bash
sudo grep samba-auth /var/log/kitsalud/clinica01/auth.log | grep -E "WRONG_PASSWORD|LOCKED_OUT|ACCOUNT_DISABLED|NO_SUCH_USER" | tail
```

```
2026-11-04T09:54:08.798968-05:00 clinica01 samba-auth:  Auth: [SMB2,NTLMSSP] user [SALUD]\[prueba.operacion] with [NTLMv2] status [NT_STATUS_ACCOUNT_LOCKED_OUT] ... remote host [ipv4:10.20.20.11:60548]
```

La línea dice por dónde entró (`SMB2` para los recursos compartidos, `LDAP` para la consulta de prerregistros y el monitoreo, `Kerberos KDC` para `kinit`), el usuario, el resultado y el equipo de origen. `NT_STATUS_OK` es un inicio de sesión correcto, `WRONG_PASSWORD` una contraseña equivocada, `LOCKED_OUT` una cuenta bloqueada por 5 intentos fallidos y `NO_SUCH_USER` un usuario que no existe. Para una persona se agrega `| grep ana.rojas`.

### Bloqueos del firewall

```bash
sudo grep -o "fw-drop [A-Za-z0-9-]*" /var/log/kitsalud/kit01/firewall.log | sort | uniq -c | sort -rn
```

```
  40470 fw-drop IN
    377 fw-drop F-20
    112 fw-drop br-srv
     64 fw-drop F-21
     16 fw-drop F-18
```

| Etiqueta | Qué se bloqueó |
|---|---|
| `fw-drop F-20` | Un equipo de la Comunidad intentó llegar a la red Interna, a clinica01 o a la gestión de kit01 |
| `fw-drop F-21` | Un SSH desde un equipo de la Interna sin dirección de administración, o por IPv6 |
| `fw-drop F-18` | kit01 intentó salir a Internet por un puerto que no está permitido |
| `fw-drop br-srv` | Una máquina virtual intentó llegar a un servicio de la otra que no está permitido |
| `fw-drop IN=...` | Cualquier otra cosa sin regla |

```bash
sudo grep "fw-drop F-20" /var/log/kitsalud/kit01/firewall.log | tail
```

```
2026-11-02T18:53:58.687935-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=lan0.10 ... SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0010:... PROTO=TCP ... DPT=22 SYN
```

`IN` es la red de donde vino (`br-com` es la Comunidad, `lan0.10` la Interna, `br-srv` los servidores y `enp170s0` la WAN), `SRC` y `DST` las direcciones y `DPT` el puerto al que intentó llegar.

**El ruido de la WAN.** Casi todas las líneas `fw-drop IN=enp170s0` son difusiones de la red del sitio (anuncios de otros equipos, DHCP de terceros) que llegan por el cable de Internet. Son normales y no son ataques. Para ver solo lo que pasa dentro del kit se deja fuera la WAN.

```bash
sudo grep fw-drop /var/log/kitsalud/kit01/firewall.log | grep -v "IN=enp170s0" | tail
```

### Direcciones entregadas por el DHCP

```bash
sudo grep DHCP4_LEASE_ALLOC /var/log/kitsalud/kit01/dhcp.log | tail
```

```
2026-11-04T07:04:32.466210-05:00 kit01 kea-dhcp4[208167]: INFO  [kea-dhcp4.leases] DHCP4_LEASE_ALLOC [hwtype=1 0e:2e:ec:c9:5e:24], ... lease 10.20.40.116 has been allocated for 3600 seconds
```

La línea trae la MAC del equipo, la dirección que recibió y la duración. La red sale de la dirección (`10.20.10.x` Interna, `10.20.40.x` Comunidad). Para un equipo, `sudo grep -i <mac> /var/log/kitsalud/kit01/dhcp.log`. Kea guarda los préstamos en `/var/lib/kea/`. En IPv6 los equipos forman su dirección solos (SLAAC) y el DHCPv6 solo entrega el DNS, así que no hay préstamos.

### Consultas al DNS

```bash
sudo tail /var/log/named/consultas.log
sudo grep "pacientes.salud.movil" /var/log/named/consultas.log | tail
```

```
04-Nov-2026 09:57:07.563 queries: client @0x7e4ca40061a8 fd5a:fc7e:d716:20::10#45847 (pacientes.salud.movil): query: pacientes.salud.movil IN A + (fd5a:fc7e:d716:20::10)
```

Después de `client` va la dirección del equipo que preguntó, luego el nombre, el tipo (`A` para IPv4, `AAAA` para IPv6) y entre paréntesis la dirección del DNS que respondió.

### El switch

```bash
sudo tail /var/log/kitsalud/sw01/syslog.log
```

```
2026-11-02T18:56:25-05:00 sw01 user admin logged out from 10.20.10.1 via ssh
```

### Un servicio o una aplicación

```bash
journalctl -u <servicio> --since -15min                 # un servicio en su equipo, por ejemplo named o samba-ad-dc
journalctl -t kit-apagado -t kit-ups --since today      # apagados ordenados y UPS lógica, en kit01
cd /srv/dhis2 && sudo docker compose logs --since 15m core    # DHIS2, en clinica01
sudo docker logs --since 15m <contenedor>               # cualquier contenedor, por ejemplo caddy-caddy-1
```

## Rotación

| Log | Cada cuánto rota | Cuánto se guarda |
|---|---|---|
| `/var/log/kitsalud/*/*.log` | Cada semana, o antes si un archivo pasa de 100 MB | 4 copias comprimidas, un mes |
| `/var/log/named/consultas.log` | Cuando llega a 20 MB | 5 archivos, unos 100 MB |
| `/var/log/samba/auth.log` en clinica01 | Cada semana | 8 copias, dos meses |
| Journal de cada equipo | Lo maneja systemd | Hasta el 10 % del disco. En kit01 ocupa 307 MB |

Las copias anteriores se leen con `zgrep` (por ejemplo `sudo zgrep "fw-drop F-20" /var/log/kitsalud/kit01/firewall.log.2.gz`). Los logs no van en la copia de respaldo semanal, porque son de diagnóstico.

## Comprobación hecha en el kit

El 4 de noviembre de 2026 se ejecutaron en kit01 todos los comandos de este procedimiento y las salidas de ejemplo son las que dieron. En ese momento el log central ocupaba 16 MB de clinica01, 23 MB de comunidad01, 36 MB de kit01 y 60 KB de sw01, más 55 MB de consultas DNS. El bloqueo de una cuenta de prueba del dominio por 5 contraseñas equivocadas quedó en el log central con su hora.
