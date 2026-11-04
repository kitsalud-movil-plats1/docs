# Máquinas virtuales

Esta parte crea las dos máquinas virtuales en kit01 y despliega en ellas las aplicaciones, la publicación de contenido, las copias y el monitoreo. Todo se hace desde la máquina de control, porque las VMs solo aceptan SSH desde kit01 y Ansible salta por él.

## Lo que se necesita

- kit01 desplegado ([kit01](kit01.md)), con su salida a Internet funcionando. Las VMs descargan paquetes, imágenes de contenedores y el contenido de la biblioteca y los videos por HTTP y HTTPS.
- El disco USB de copias conectado a kit01 (paso 6).

## Las máquinas virtuales

| VM | vCPU | RAM | Discos | MAC | Direcciones |
|---|---|---|---|---|---|
| `clinica01` | 4 | 7 GB | 40 GB de sistema y 120 GB de datos en `/srv` | `52:54:00:20:00:11` | `10.20.20.11/24` y `fd5a:fc7e:d716:20::11/64` |
| `comunidad01` | 2 | 2,5 GB | 20 GB de sistema y 120 GB de datos en `/srv` | `52:54:00:20:00:12` | `10.20.20.12/24` y `fd5a:fc7e:d716:20::12/64` |
| `prueba01` | 1 | 512 MB | 10 GB | `52:54:00:40:00:50` | Por DHCP en la Comunidad. Hace de cliente para las pruebas y queda apagada |

Están definidas en `platform/ansible/inventarios/kit/group_vars/all/maquinas.yml`. Los discos son qcow2 independientes, con aprovisionamiento delgado, en el volumen lógico `ubuntu-vg/vms` montado en `/var/lib/libvirt/images`. Las dos VMs del kit se conectan al bridge `br-srv` y arrancan solas con kit01.

## Playbooks

Se ejecutan desde `kitsalud/platform/ansible`, en este orden. Igual que en kit01, cada uno debe terminar sin `failed` ni `unreachable`, y si uno falla se corrige y se repite el mismo.

| # | Comando | Qué deja | Por qué en este lugar |
|---|---|---|---|
| 1 | `ansible-playbook playbooks/vms.yml` | Volumen lógico de 320 GiB, imagen de Ubuntu 24.04 verificada con su `SHA256SUMS` y las tres VMs creadas con cloud-init. Después aplica a clinica01 y comunidad01 la base común (usuario `kitsalud`, SSH solo desde kit01 con ufw, hora desde kit01 y envío de logs a kit01) | Necesita los bridges, el DNS, la hora y el receptor de logs de kit01 |
| 2 | `ansible-playbook playbooks/samba.yml` | Controlador de dominio `ad.salud.movil` en clinica01, con sus grupos, usuarios y política de contraseñas, y los recursos `archivos` y `contenido` | La consulta de prerregistros, Grafana y la publicación usan el dominio o sus recursos |
| 3 | `ansible-playbook playbooks/clinica01.yml` | Docker, DHIS2 con PostgreSQL y la base de prerregistros, el intermedio de la CA de clinica01, el certificado LDAPS del dominio, la consulta de prerregistros y Caddy en HTTPS | La consulta entra con LDAPS al dominio y la base de prerregistros la usa comunidad01 |
| 4 | `ansible-playbook playbooks/comunidad01.yml` | Docker, la biblioteca (Kiwix), los videos (Jellyfin, con su contenido), el intermedio de la CA de comunidad01, el formulario de prerregistro y Caddy | El formulario escribe en la base de clinica01 |
| 5 | `ansible-playbook playbooks/publicacion.yml` | En clinica01, los archivos de la biblioteca en `contenido/zim`, el usuario y la llave de la publicación y su timer cada 10 minutos. En comunidad01, el destino que solo acepta esa llave | Copia el recurso `contenido` de clinica01 a comunidad01 y respeta los videos que puso el paso 4 |
| 6 | `ansible-playbook playbooks/backups.yml` | restic, la clave del repositorio y el timer semanal en kit01, y en cada VM el usuario `backup` que solo permite extraer | Necesita las bases, el dominio y los recursos que dejan los pasos 2 a 5 |
| 7 | `ansible-playbook playbooks/monitoreo.yml` | node_exporter en los tres equipos, y en kit01 Prometheus con las sondas, blackbox, nginx y Grafana con entrada por el dominio | Prueba todos los servicios, así que va al final |
| 8 | `ansible-playbook playbooks/red-kit01.yml --check --diff` | Nada. Comprueba que el firewall sigue igual, ahora con las sondas y los flujos entre las VMs | Desde aquí se ejecuta siempre sin los `-e` del primer despliegue |

### Disco de copias (antes del paso 6)

Si el disco es nuevo, se formatea en kit01 con una partición `kitbackup` en ext4 y su UUID se escribe en `backup_disco_uuid` de `inventarios/kit/group_vars/all/backups-equipos.yml`. Antes de borrar se confirma con `lsblk` que el dispositivo es el disco USB, por su tamaño, su serie y `TRAN usb`.

```bash
lsblk -o NAME,SIZE,SERIAL,TRAN,MODEL                   # identificar el disco, por ejemplo /dev/sdX
sudo sgdisk -Z /dev/sdX && sudo sgdisk -n1:0:0 -t1:8300 -c1:kitbackup /dev/sdX
sudo mkfs.ext4 -m 0 -L kitbackup -E lazy_itable_init=0 /dev/sdX1
sudo blkid -s UUID -o value /dev/sdX1                  # va en backup_disco_uuid
```

El playbook no deja el disco montado. La copia lo monta solo mientras dura y, si el disco no tiene repositorio, lo crea con la clave del vault.

## Lo que queda instalado en las VMs

**En las dos**

| Servicio | Paquete y versión | Archivos de configuración | Unidad de systemd |
|---|---|---|---|
| Base | Ubuntu 24.04.5 desde la imagen cloud `release-20260926` | `/etc/ssh/sshd_config.d/10-comun.conf`, reglas de ufw | `ssh`, `ufw` |
| Hora | `chrony` 4.5, retenido | `/etc/chrony/chrony.conf` con `ntp.salud.movil` como única fuente | `chrony` |
| Envío de logs | `rsyslog` del sistema | `/etc/rsyslog.d/90-reenvio.conf`, con cola en disco | `rsyslog` |
| Contenedores | `docker.io` 29.1.3 y `docker-compose-v2` 2.40.3, retenidos | `/etc/docker/daemon.json` | `docker` |
| Monitoreo | `prometheus-node-exporter` 1.7.0, retenido | `/etc/default/prometheus-node-exporter` | `prometheus-node-exporter` |
| Copias | Ninguno | `/etc/ssh/sshd_config.d/20-backup.conf`, `/etc/sudoers.d/backup`, `/usr/local/sbin/backup-extraer`, `/etc/kitsalud/backup/rsyncd.conf` | Ninguna (lo invoca kit01) |

**clinica01**

| Servicio | Paquete o imagen | Archivos de configuración | Cómo corre |
|---|---|---|---|
| Dominio y archivos | `samba-ad-dc` 4.19.5 y `krb5-user` 1.20.1, retenidos | `/etc/samba/smb.conf`, `/etc/krb5.conf`, recursos en `/srv/samba/` | `samba-ad-dc` |
| Historia clínica | `dhis2/core:2.42.6.0` y `postgis/postgis:16-3.5` | `/srv/dhis2/compose.yml`, `.env`, `pg_hba.conf`, metadatos en `kit.json` | Compose `dhis2` |
| Consulta de prerregistros | `kitsalud/consultas:1`, construida en la VM | `/srv/consultas/compose.yml` y `.env` | Compose `consultas` |
| HTTPS | `caddy:2.11.7` | `/srv/caddy/compose.yml`, `/srv/caddy/conf/Caddyfile`, intermedio en `/srv/caddy/pki/` | Compose `caddy` |
| Publicación | `rsync` del sistema | `/usr/local/sbin/publicar-contenido`, llave en `/var/lib/publicacion/` | `publicacion.timer` |

**comunidad01**

| Servicio | Imagen | Archivos de configuración | Cómo corre |
|---|---|---|---|
| Biblioteca | `ghcr.io/kiwix/kiwix-serve:3.8.2` | `/srv/kiwix/compose.yml`, archivos en `/srv/medios/zim/` | Compose `kiwix` y `kiwix-recarga.path`, que la reinicia cuando cambian los archivos |
| Videos | `jellyfin/jellyfin:12.3.20261023-013714` | `/srv/jellyfin/compose.yml`, videos en `/srv/medios/videos/` | Compose `jellyfin` |
| Formulario de prerregistro | `kitsalud/formularios:1`, construida en la VM | `/srv/formularios/compose.yml` y `.env` | Compose `formularios` |
| HTTPS y HTTP | `caddy:2.11.7` | `/srv/caddy/compose.yml`, `/srv/caddy/conf/Caddyfile` | Compose `caddy` |
| Destino de la publicación | `rsync` del sistema | `/etc/ssh/sshd_config.d/20-publicacion.conf`, `/etc/kitsalud/publicacion/rsyncd.conf` | Lo invoca clinica01 por SSH |

**En kit01, de los pasos 6 y 7**

| Servicio | Paquete y versión | Archivos de configuración | Unidad de systemd |
|---|---|---|---|
| Copias | `restic` 0.16.4, retenido | `/usr/local/sbin/backup-kit`, `/etc/kitsalud/backup/` (llave y clave del repositorio) | `backup.timer`, el domingo a las 4:00 |
| Métricas y sondas | `prometheus` 2.45.3, `prometheus-blackbox-exporter` 0.24.0 y `prometheus-node-exporter` 1.7.0, retenidos | `/etc/prometheus/prometheus.yml`, `/etc/prometheus/reglas/alertas.yml`, `/etc/prometheus/blackbox.yml` | `prometheus`, `prometheus-blackbox-exporter`, `prometheus-node-exporter` |
| Paneles | `grafana` 13.2.4 desde `apt.grafana.com`, retenido | `/etc/grafana/`, paneles en `/var/lib/grafana/dashboards/`, `/etc/nginx/sites-available/monitoreo` | `grafana-server`, `nginx` |

Las imágenes de contenedores van con versión fija en cada `compose.yml`, así que volver a desplegar baja siempre la misma.

**Probado el 2026-11-04.** PENDIENTE resultado del `--check`.
