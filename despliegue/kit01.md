# kit01

kit01 es el mini PC Beelink EQi12 que hace de router, firewall e hipervisor. Esta parte lo instala desde cero y despliega con Ansible todo lo que corre en él antes de crear las máquinas virtuales, es decir, la red, el firewall, el DNS, la hora, el DHCP, el portal cautivo, el receptor de logs, la CA del kit y la UPS lógica.

## Lo que se necesita

- La máquina de control lista ([Preparación](preparacion.md)).
- Monitor, teclado y la memoria USB con Ubuntu Server 24.04.5 LTS, solo para la instalación.
- `enp170s0` conectado a la red del sitio y `enp171s0` a `ether1` de sw01.
- Los datos de la red del sitio, que son la IP fija de kit01, el gateway y los DNS, o saber que entrega DHCP.

## 1. Instalar Ubuntu Server

En el instalador de Ubuntu Server 24.04.5 se eligen estos valores. Lo que no aparece en la tabla se deja como viene.

| Pantalla | Valor |
|---|---|
| Red | `enp170s0` con la IP del sitio (en el laboratorio, `192.168.160.69/24`, gateway `192.168.160.1`) y `enp171s0` sin configurar |
| Almacenamiento | Disco completo con **LVM**. El instalador crea `/boot/efi` de 1 GB, `/boot` de 2 GB y el grupo `ubuntu-vg` con `/` de 100 GiB, y deja el resto del grupo libre. Ese espacio libre es el que después usan los discos de las máquinas virtuales, así que `/` no se agranda |
| Perfil | Nombre del servidor `kit01` y usuario `kitsalud` con la contraseña del vault (`vault_admin_password`) |
| SSH | **Install OpenSSH server**, con contraseña |
| Paquetes extra | Ninguno |

Al terminar, desde la consola de kit01, se actualiza el sistema, se desactiva cloud-init para que no cambie el nombre ni la red en los arranques siguientes y se reinicia.

```bash
sudo apt-get update && sudo apt-get -y full-upgrade
sudo touch /etc/cloud/cloud-init.disabled
sudo reboot
```

**Cómo comprobarlo**

```bash
lsb_release -d                     # Ubuntu 24.04.5 LTS
ip -br link                        # enp170s0 y enp171s0, con esos nombres
sudo vgs ubuntu-vg                 # VFree de unos 370 GiB
lscpu | grep -i virtualization     # VT-x
```

## 2. NetBird

Desde la consola de kit01 se instala NetBird, se registra con la clave de la consola del grupo y se retiene para que una actualización no lo reinicie a mitad de una sesión.

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
 sudo netbird up --setup-key '<clave-de-registro>'   # con un espacio al inicio
sudo apt-mark hold netbird
netbird status | grep -E 'Management|Signal|NetBird IP'
```

La dirección que muestra `NetBird IP` se escribe en `ansible_host` de kit01 en `platform/ansible/inventarios/kit/hosts.yml`. Desde aquí todo se hace en remoto desde la máquina de control, y el monitor y el teclado ya no hacen falta.

## 3. Datos del sitio en el inventario

Lo único que cambia de un sitio a otro es la WAN de kit01. Está en `platform/ansible/inventarios/kit/host_vars/kit01.yml`.

```yaml
wan:
  ipv4: 192.168.160.69/24          # o "dhcp4: true" si el sitio entrega DHCP
  gw4: 192.168.160.1
  dns: [192.168.215.20, 192.168.215.30]
```

Las direcciones internas del kit (VLAN, prefijos IPv4 e IPv6, IP de cada servicio) están definidas una sola vez en `inventarios/kit/group_vars/all/red.yml` y no cambian con el sitio.

Después se acepta la clave de host de kit01 y se comprueba el acceso, como en la preparación.

```bash
cd kitsalud/platform/ansible
sshpass -f ~/.config/kitsalud/ssh-pass ssh -o StrictHostKeyChecking=accept-new kitsalud@<ip-netbird-de-kit01> hostname
ansible kit01 -m ping
```

## 4. Playbooks del host

Todos se ejecutan desde `kitsalud/platform/ansible`, en este orden y uno por vez. Cada uno termina con un `PLAY RECAP` que no debe tener `failed` ni `unreachable`. Si uno falla, se corrige la causa y se vuelve a ejecutar el mismo, porque todos son idempotentes (una segunda ejecución termina en `changed=0`).

| # | Comando | Qué deja | Por qué en este lugar |
|---|---|---|---|
| 1 | `ansible-playbook playbooks/comun.yml -l kit01` | Usuario `kitsalud` en los grupos `libvirt` y `kvm`, SSH sin root y zona horaria `America/Bogota` | Es la base de todo lo demás |
| 2 | `ansible-playbook playbooks/kit01.yml` | Nombre `kit01.salud.movil`, QEMU/KVM y libvirt, la red `default` de libvirt apagada y NetBird retenido | La red `default` de libvirt tiene que estar apagada antes del firewall, porque trae su propio NAT |
| 3 | `ansible-playbook playbooks/red-kit01.yml` (ver abajo) | Firewall con nftables, VLAN, bridges de las VMs y de la Comunidad, direcciones IPv4 e IPv6 y reenvío | Los servicios que siguen escuchan en las direcciones que crea este paso |
| 4 | `ansible-playbook playbooks/dns.yml` | BIND9 con la zona `salud.movil` y sus inversas, recursivo para el kit | Las VMs resuelven nombres con él desde el primer arranque |
| 5 | `ansible-playbook playbooks/ntp.yml` | Chrony como servidor de hora del kit, que sigue sirviendo hora sin Internet | Las VMs, sw01 y el dominio necesitan la misma hora |
| 6 | `ansible-playbook playbooks/dhcp.yml` | Kea DHCPv4, Kea DHCPv6 sin estado y radvd en la Interna y en la Comunidad | Los clientes reciben dirección, DNS y hora |
| 7 | `ansible-playbook playbooks/portal.yml` | nginx con el portal cautivo y el servicio que autoriza a cada cliente de la Comunidad | La redirección y el set de clientes ya los puso el firewall |
| 8 | `ansible-playbook playbooks/registros.yml` | Receptor central de rsyslog, con una carpeta por equipo | Recibe los logs de las VMs desde su primer arranque |
| 9 | `ansible-playbook playbooks/ca.yml` | Raíz de la CA del kit y el certificado de `monitoreo` | Firma los intermedios de las VMs y los certificados de sus servicios |
| 10 | `ansible-playbook playbooks/nut.yml` | UPS lógica y el apagado ordenado `kit-apagado` | Apaga las VMs en orden cuando existan |

### El firewall y la red (paso 3)

Este paso es el único que puede cortar el acceso a kit01, así que se hace con cuidado. El playbook acepta siempre NetBird y SSH, compara lo nuevo con lo activo y solo recarga si cambia. Cuando recarga, programa la vuelta a la configuración anterior a los pocos minutos y solo la cancela si vuelve a entrar y NetBird sigue conectado.

En el primer despliegue todavía no existen las VMs ni Prometheus, y el playbook normalmente los usa para comprobar el firewall nuevo. Por eso la primera vez se ejecuta sin esas comprobaciones. Las siguientes veces se ejecuta sin los `-e`.

```bash
ansible-playbook playbooks/red-kit01.yml --check --diff \
  -e kit01_firewall_sondas=false -e '{"kit01_firewall_comprobaciones": []}'   # qué cambiaría
ansible-playbook playbooks/red-kit01.yml \
  -e kit01_firewall_sondas=false -e '{"kit01_firewall_comprobaciones": []}'   # aplicar
```

Mientras se aplica conviene tener abierta una segunda sesión SSH a kit01. Si el acceso se corta, se espera a que actúe la restauración y se vuelve a entrar.

**Cómo comprobarlo**

```bash
ansible kit01 -b -m shell -a 'ip -br addr; nft list tables; sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding'
```

`lan0.10` con `10.20.10.1/24`, `br-com` con `10.20.40.1/24` y `br-srv` con `10.20.20.1/24`, cada uno con su dirección `fd5a:fc7e:d716:<vlan>::1/64` y `fe80::1`. `br-srv` tiene además las direcciones de los servicios de kit01, `10.20.20.10` y `fd5a:fc7e:d716:20::10`. Deben aparecer las tablas `inet filtro`, `ip nat_kit` y `bridge filtro_vms`, y el reenvío en `1` en las dos familias.

## Lo que queda instalado en kit01

| Servicio | Paquete y versión | Archivos de configuración | Unidad de systemd |
|---|---|---|---|
| Base | `openssh-server` del instalador | `/etc/ssh/sshd_config.d/10-comun.conf`, `/etc/hosts` | `ssh` |
| Virtualización | `qemu-kvm` (QEMU 8.2.2), `libvirt-daemon-system` (10.0.0), `virtinst` (4.1.0) | Definiciones de las VMs en libvirt | `libvirtd`, `libvirt-guests` |
| Acceso remoto | `netbird` 0.80.0, retenido | La de NetBird, sin cambios | `netbird` |
| Firewall | `nftables` del sistema | `/etc/nftables.conf`, `/etc/nftables/quitar.nft`, `/etc/systemd/system/nftables.service.d/kit01.conf` | `nftables` |
| Red | `netplan.io` del sistema | `/etc/netplan/50-cloud-init.yaml`, `/etc/sysctl.d/60-kit01-router.conf` | `systemd-networkd` |
| DNS | `bind9` 9.18.39, retenido | `/etc/bind/named.conf.options`, `/etc/bind/named.conf.local`, `/etc/bind/zonas/` | `named` |
| Hora | `chrony` 4.5, retenido | `/etc/chrony/chrony.conf` | `chrony` |
| DHCP e IPv6 | `kea-dhcp4-server` y `kea-dhcp6-server` 2.4.1, `radvd` 2.19, retenidos | `/etc/kea/kea-dhcp4.conf`, `/etc/kea/kea-dhcp6.conf`, `/etc/radvd.conf` | `kea-dhcp4-server`, `kea-dhcp6-server`, `radvd` |
| Portal cautivo | `nginx` 1.24.0, retenido | `/etc/nginx/conf.d/kitsalud.conf`, `/etc/nginx/sites-available/portal`, `/usr/local/lib/kitsalud-portal/portal.py`, `/usr/share/kitsalud-portal/` | `nginx`, `kitsalud-portal` |
| Logs | `rsyslog` 8.2312.0, retenido | `/etc/rsyslog.d/30-kitsalud-central.conf`, `/etc/logrotate.d/kitsalud-registros`, logs en `/var/log/kitsalud/` | `rsyslog` |
| CA del kit | `openssl` del sistema | `/etc/kitsalud/ca/` (la llave de la raíz solo aquí, con permisos `600`), `/etc/kitsalud/tls/` | Ninguna |
| UPS lógica | `nut-server` y `nut-client` 2.8.1, retenidos | `/etc/nut/`, `/etc/kitsalud/nut/`, `/usr/local/sbin/kit-ups`, `/usr/local/sbin/kit-apagado` | `nut-server`, `nut-monitor`, `kit-ups-inicial` |

Los paquetes con versión fija quedan retenidos con `apt-mark hold`, así que una actualización general no los cambia. `apt-mark showhold` en kit01 los lista.

**Probado el 2026-11-04.** Los diez playbooks de esta parte, ejecutados con `--check --diff` contra kit01, terminaron en `changed=0`. El kit real no se reinstaló, porque eso cortaría el acceso remoto. La primera ejecución de `red-kit01.yml` sin las comprobaciones es la misma que se usó en el laboratorio virtual, donde la red y el firewall se desplegaron desde un Ubuntu recién instalado.
