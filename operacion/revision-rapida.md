# Revisión rápida del kit

Este procedimiento sirve para saber en pocos minutos si el kit está bien y, si algo falla, encontrar qué es y volverlo a poner en marcha. Está pensado para cualquier integrante de la brigada que tenga acceso de administración, aunque no haya instalado el kit.

## Lo que se necesita

- Un equipo conectado a la red Interna con una dirección de administración (de `10.20.10.10` a `10.20.10.29`, reservada por MAC), o la conexión remota por NetBird.
- El usuario de administración del kit y su contraseña.
- Un navegador para abrir el monitoreo en `https://monitoreo.salud.movil`, con una cuenta del grupo de administración del dominio. Si el dominio no responde, sirve la cuenta local `admin` de Grafana.

El kit tiene tres equipos con sistema. **kit01** es el mini PC que hace de router, firewall, DNS, DHCP y hora, y donde corren las otras dos máquinas. **clinica01** tiene la historia clínica (DHIS2), la base de datos, el dominio, los archivos compartidos y la consulta de prerregistros. **comunidad01** tiene la biblioteca, los videos y el formulario de prerregistro.

Para entrar por SSH se usan estos comandos.

```bash
ssh <usuario>@10.20.10.1                              # kit01 desde la red Interna
ssh -J <usuario>@10.20.10.1 <usuario>@10.20.20.11     # clinica01, saltando por kit01
ssh -J <usuario>@10.20.10.1 <usuario>@10.20.20.12     # comunidad01, saltando por kit01
```

Por NetBird, kit01 es `100.90.225.113`.

## Paso 1. Mirar el tablero

Abrir `https://monitoreo.salud.movil`. La página de inicio es **Estado del kit**.

| Recuadro | Lo normal | Si no |
|---|---|---|
| **Problemas ahora** | 0 | Hay alertas activas; ver **Qué está fallando** |
| **Equipos** | kit01, clinica01, comunidad01, el switch y el Wi-Fi encendidos | Un equipo no responde; ver el paso 3, síntoma 1 |
| **Servicios** | Todos en verde | El servicio en rojo dice por dónde empezar |
| **Qué está fallando** | Vacía | Cada fila dice qué falla, en qué equipo y si es en IPv4 o IPv6 |

Cada servicio se prueba cada 15 segundos en IPv4 y en IPv6, y se pone en rojo a los 30 segundos de fallar. Si todo está en verde y alguien reporta un problema, seguir con el paso 3 por el síntoma que describe.

## Paso 2. Revisar kit01 en un minuto

Se ejecuta en kit01. `virsh` necesita `-c qemu:///system`; sin eso consulta las máquinas del propio usuario y muestra la lista vacía.

```bash
systemctl --failed                     # servicios caídos
virsh -c qemu:///system list --all   # clinica01 y comunidad01 en "running"
df -h / /var/lib/libvirt/images        # espacio en disco
chronyc tracking | grep -E "Stratum|Leap"
```

| Comando | Lo normal |
|---|---|
| `systemctl --failed` | `0 loaded units listed`. Si aparece `systemd-networkd-wait-online` y kit01 no se ha reiniciado desde octubre, es un registro viejo y no afecta |
| `virsh -c qemu:///system list --all` | `clinica01` y `comunidad01` en `running`. `prueba01` apagada es lo normal |
| `df -h` | Por debajo del 80 %, que es donde salta la alerta **DiscoAlto** |
| `chronyc tracking` | `Leap status : Normal`. Con Internet el estrato es 2 o 3. Sin Internet conserva la última referencia y, si el corte se alarga, pasa a estrato 10 y sigue sirviendo la hora |

## Paso 3. Buscar por síntoma

Los comandos con `sudo` se ejecutan en el equipo indicado. Después de arreglar, volver al tablero y esperar a que todo esté en verde.

| # | Síntoma | Dónde | Revisar | Arreglar |
|---|---|---|---|---|
| 1 | Un equipo aparece apagado, o nada de clinica01 o de comunidad01 responde | kit01 | `virsh -c qemu:///system list --all` | `virsh -c qemu:///system start clinica01` o `virsh -c qemu:///system start comunidad01`. Los servicios vuelven solos en 1 o 2 minutos |
| 2 | **Nombres de la red (DNS)** en rojo, o los equipos no abren `pacientes.salud.movil` pero sí `https://10.20.20.11` | kit01 | `systemctl status named` y `dig @10.20.20.10 pacientes.salud.movil` (debe responder `10.20.20.11`) | `sudo systemctl restart named`. Si no arranca, `sudo named-checkconf` dice qué archivo tiene el error |
| 3 | **Direcciones de la red (DHCP)** en rojo, o los equipos nuevos no obtienen dirección | kit01 | `systemctl status kea-dhcp4-server kea-dhcp6-server radvd` y `ip link show enp171s0` (debe decir `UP`) | `sudo systemctl restart kea-dhcp4-server kea-dhcp6-server radvd`. Si `enp171s0` no tiene enlace, revisar el cable hacia el switch (puerto 1) |
| 4 | **Historia clínica (DHIS2)** o **Base de datos** en rojo | clinica01 | `cd /srv/dhis2 && sudo docker compose ps` (deben estar `db` y `core` en `healthy`) | `sudo docker compose up -d`. DHIS2 tarda cerca de un minuto en volver a responder |
| 5 | **Archivos compartidos** o **Inicio de sesión (AD)** en rojo, o nadie entra con su usuario | clinica01 | `systemctl status samba-ad-dc` | `sudo systemctl restart samba-ad-dc`. Si un usuario dice que su cuenta está bloqueada, se desbloquea sola a los 15 minutos |
| 6 | **Consulta de prerregistros** en rojo | clinica01 | `cd /srv/consultas && sudo docker compose ps` | `sudo docker compose up -d` |
| 7 | **Biblioteca**, **Videos** o **Registro de pacientes** en rojo | comunidad01 | `sudo docker ps` (deben estar `kiwix`, `jellyfin`, `formularios` y `caddy`) | En la carpeta del que falta (`/srv/kiwix`, `/srv/jellyfin`, `/srv/formularios` o `/srv/caddy`), `sudo docker compose up -d` |
| 8 | El formulario dice que no pudo guardar los datos | clinica01 | La base de datos (síntoma 4) | Al volver la base, la persona toca Enviar otra vez; lo escrito no se pierde |
| 9 | **Portal de la Comunidad** en rojo, o los celulares de la Comunidad no ven el portal | kit01 | `systemctl status nginx kitsalud-portal` | `sudo systemctl restart nginx kitsalud-portal`. En el celular, abrir una dirección con `http://` (por ejemplo `http://biblioteca.salud.movil`); las de `https://` no muestran el portal |
| 10 | No hay Internet | kit01 | `ip link show enp170s0` y `ping -c 3 1.1.1.1` | Es esperable en campo. Todos los servicios del kit siguen funcionando. Si debería haber Internet, revisar el cable de la WAN |
| 11 | **Hora del kit (NTP)** en rojo, o un equipo tiene la hora mal | kit01 | `systemctl status chrony` y `chronyc tracking` | `sudo systemctl restart chrony` |
| 12 | Alguien no llega a un servicio que debería ver | kit01 | `sudo tail -20 /var/log/kitsalud/kit01/firewall.log`. Cada bloqueo trae la dirección de origen y la de destino | Si el bloqueo es correcto (por ejemplo, un celular de la Comunidad que intenta entrar a la historia clínica), no hay nada que hacer |
| 13 | Una alerta de disco (**DiscoAlto**) | El equipo de la alerta | `df -h` y `sudo du -xh / --max-depth=2 \| sort -h \| tail` | Avisar al responsable técnico antes de borrar nada |
| 14 | La copia de respaldo falló (`backup` en **Qué está fallando**) | kit01 | `journalctl -u backup -o cat \| tail -20` y `lsblk -f` (debe aparecer `kitbackup`) | Conectar el disco USB de respaldo y ejecutar `sudo systemctl start backup.service` |

## Dónde están los logs

Todos los equipos envían sus logs a kit01, a una carpeta por equipo en `/var/log/kitsalud/`.

| Archivo | Qué tiene |
|---|---|
| `/var/log/kitsalud/<equipo>/syslog.log` | Todo lo del equipo (`kit01`, `clinica01`, `comunidad01` o `sw01`) |
| `/var/log/kitsalud/<equipo>/auth.log` | Inicios de sesión, `sudo` y accesos rechazados. En clinica01 también los del dominio |
| `/var/log/kitsalud/kit01/firewall.log` | Lo que bloqueó el firewall |
| `/var/log/kitsalud/kit01/dhcp.log` | Direcciones entregadas |
| `/var/log/kitsalud/kit01/dns.log` | Mensajes del DNS |

Para seguir un archivo mientras se reproduce el problema, `sudo tail -f <archivo>`. Para un servicio concreto en su equipo, `journalctl -u <servicio> --since -15min`.

## Al terminar

El tablero vuelve a mostrar **Problemas ahora** en 0 y todos los servicios en verde. Si un problema se repite o no se arregla con este procedimiento, anotar la hora, el síntoma y lo que mostraron los comandos, y avisar al responsable técnico.
