# Preparación

Todo el despliegue se ejecuta desde una máquina de control, que es el portátil del administrador. Esta parte la deja lista con Ansible, los repositorios del kit y los secretos, y comprueba que llega a los equipos. Se hace una vez por máquina.

## Lo que se necesita

| Qué | Para qué |
|---|---|
| Portátil con Linux (Ubuntu 24.04 o similar), Internet y sudo | Máquina de control. En macOS los pasos son los mismos con Homebrew en lugar de `apt` |
| Una cuenta en la red de NetBird del grupo y su clave de registro | Llegar a kit01 en remoto, durante el despliegue y después |
| La contraseña del vault, que el grupo comparte por un canal privado | Abrir los secretos del kit (contraseñas de los usuarios, de las bases y de las copias) |
| Memoria USB de 4 GB o más | Instalador de Ubuntu Server 24.04.5 para kit01 |
| Cable de consola RJ45 a USB | Configurar el switch desde cero |
| Disco USB para las copias | Repositorio de restic, conectado a kit01 |

## 1. Paquetes de la máquina de control

Ansible se instala con `pipx` en la misma versión que se usó para desplegar el kit, y las colecciones también con versión fija.

```bash
sudo apt-get update
sudo apt-get install -y git sshpass openssh-client pipx
pipx install ansible-core==2.20.7
export PATH="$HOME/.local/bin:$PATH"          # o abrir una terminal nueva después de "pipx ensurepath"
ansible-galaxy collection install ansible.posix:==2.2.0 community.general:==12.6.2 community.crypto:==3.2.2
```

| Paquete | Versión | Para qué |
|---|---|---|
| `ansible-core` | 2.20.7 | Ejecutar los playbooks |
| `ansible.posix`, `community.general`, `community.crypto` | 2.2.0, 12.6.2, 3.2.2 | Montajes, LVM, ufw, zona horaria y la CA del kit |
| `sshpass` | La de la distribución | Entrar con contraseña a kit01 y, saltando por kit01, a las máquinas virtuales |
| `git` | La de la distribución | Clonar los repositorios |

**Cómo comprobarlo**

```bash
ansible --version | head -1                        # ansible [core 2.20.7]
ansible-galaxy collection list | grep -E 'ansible.posix|community.(general|crypto)'
```

## 2. Repositorios

Los roles de Ansible viven en cuatro repositorios distintos y se encuentran entre sí por su posición, así que se clonan uno al lado del otro dentro del espacio de trabajo. El script `clonar-repos.sh` lo hace y, si ya existen, los actualiza.

```bash
git clone https://github.com/kitsalud-movil-plats1/workspace.git kitsalud
kitsalud/scripts/clonar-repos.sh
```

| Carpeta | Qué tiene |
|---|---|
| `kitsalud/network` | Red y firewall de kit01, DHCP, anuncios IPv6, portal cautivo, configuración del switch y revisión del punto de acceso |
| `kitsalud/platform` | Ansible (inventario, secretos y playbooks) y los roles de la base de kit01, las máquinas virtuales, DNS, hora, dominio, CA, publicación, copias y UPS |
| `kitsalud/apps` | Roles de las aplicaciones de clinica01 y comunidad01 (Docker, DHIS2, Caddy, Kiwix, Jellyfin, formularios y consulta) |
| `kitsalud/observability` | Roles de Prometheus, los exporters, Grafana y el receptor de logs |

Ansible se ejecuta siempre desde `kitsalud/platform/ansible`, porque ahí está `ansible.cfg` con el inventario, las rutas de los roles y la ubicación de la contraseña del vault.

## 3. Secretos

Las contraseñas del kit están cifradas con `ansible-vault` en `inventarios/kit/group_vars/all/vault.yml`, que sí está en el repositorio. Lo que no está es la contraseña que lo abre. Se guarda en la máquina de control con permisos `600`.

```bash
install -d -m 700 ~/.config/kitsalud
(umask 077; read -rsp 'Contraseña del vault: ' c && echo "$c" > ~/.config/kitsalud/vault-pass; echo)
cd kitsalud/platform/ansible
ansible-vault view inventarios/kit/group_vars/all/vault.yml >/dev/null && echo "vault abierto"
```

Después se crea el archivo que usa el salto por kit01 para llegar a las máquinas virtuales, porque los dos saltos piden contraseña.

```bash
ansible-playbook playbooks/preparar-control.yml    # crea ~/.config/kitsalud/ssh-pass desde el vault
```

**Para un kit nuevo con secretos propios.** Se genera una contraseña del vault y se crea el archivo con las mismas claves de `vault.example.yml`. La contraseña del usuario de administración va dos veces, en claro (`vault_admin_password`) y como hash para cloud-init (`vault_admin_password_hash`).

```bash
(umask 077; openssl rand -base64 32 > ~/.config/kitsalud/vault-pass)
openssl passwd -6                                  # pide la contraseña del usuario kitsalud y muestra su hash
ansible-vault create inventarios/kit/group_vars/all/vault.yml
```

## 4. NetBird en la máquina de control

kit01 se administra por NetBird, así que la máquina de control entra en la misma red. La clave de registro sale de la consola de NetBird del grupo y no se guarda en ningún archivo.

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
 sudo netbird up --setup-key '<clave-de-registro>'   # con un espacio al inicio, para que no quede en el historial
netbird status | grep -E 'Management|Signal'        # Connected en los dos
```

En un kit nuevo, kit01 todavía no está en NetBird. Se agrega al instalarlo y su dirección de NetBird se escribe en `inventarios/kit/hosts.yml` (ver [kit01](kit01.md)).

## 5. Comprobar el acceso

Con el kit ya instalado, la máquina de control tiene que llegar a kit01 y, a través de él, a las dos máquinas virtuales. Ansible no acepta la clave de host de un equipo nuevo cuando entra con contraseña, así que la de kit01 se acepta una vez con `ssh`. Las de las máquinas virtuales las acepta el salto por kit01.

```bash
sshpass -f ~/.config/kitsalud/ssh-pass ssh -o StrictHostKeyChecking=accept-new kitsalud@100.90.225.113 hostname   # kit01
ansible kit:vms -m ping
```

```
kit01 | SUCCESS => { "changed": false, "ping": "pong" }
clinica01 | SUCCESS => { "changed": false, "ping": "pong" }
comunidad01 | SUCCESS => { "changed": false, "ping": "pong" }
```

**Probado el 2026-11-04** en un contenedor Ubuntu 24.04 recién creado, con la red de NetBird de la máquina anfitriona y siguiendo solo esta parte. Los tres equipos respondieron `pong` y los 21 playbooks pasaron `ansible-playbook --syntax-check`.
