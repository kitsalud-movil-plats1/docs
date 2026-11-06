# Actualización del kit

Este procedimiento actualiza los paquetes de los tres equipos y deja guardadas en el disco USB las imágenes de las aplicaciones, para poder reinstalarlas sin Internet. Se hace solo en base, con Internet y en una ventana de mantenimiento, nunca en campo. Lo ideal es hacerlo antes de cada misión, con tiempo para revisar el kit después.

Cada paso se ejecuta desde la máquina de control, en `platform/ansible`, con el playbook `playbooks/actualizacion.yml` y la variable `paso`. Antes de tocar nada se saca una copia al disco USB y una instantánea de cada máquina virtual, así que cualquier paso que salga mal en una VM se deshace volviendo a la instantánea.

## Qué se actualiza y qué no

| Qué | Cómo | Qué queda fijo |
|---|---|---|
| Paquetes de `clinica01` y `comunidad01` | `apt` con todo lo que no está retenido | Docker, Samba AD, Chrony y el exportador de métricas |
| Paquetes de kit01 | `apt` con todo lo que no está retenido, sin reiniciar | BIND9, Kea, radvd, Chrony, nginx, NUT, Prometheus, Grafana, rsyslog, restic y NetBird |
| Imágenes de las aplicaciones | Se bajan las versiones fijadas en cada `compose.yml`, que no cambian solas | La versión de cada imagen |

Los paquetes retenidos (`apt-mark showhold`) son los servicios del kit cuya configuración depende de la versión y el acceso remoto. Se actualizan uno por uno y a propósito, con su propia prueba, como se explica al final. Las imágenes tienen la versión escrita en su `compose.yml`, así que `docker compose pull` nunca trae una versión distinta.

## Lo que se necesita

- La máquina de control con el Ansible del kit (la contraseña del vault en `~/.config/kitsalud/vault-pass`) y acceso a kit01 por NetBird o desde la red Interna.
- Internet en kit01.
- El disco USB de backups conectado a kit01.
- Unos 30 minutos. Cada VM queda sin servicio cerca de un minuto al sacar su instantánea y otro poco si la actualización pide reiniciarla.

## Paso 1. Revisar que todo está bien

```bash
cd docs/pruebas
./scripts/P12-reinicio.sh estado
```

Debe terminar sin fallas, con las dos VMs en marcha y ninguna sonda en rojo. Si algo ya está fallando, se arregla antes de actualizar, para no mezclar los problemas.

## Paso 2. Copia al disco USB

```bash
ssh <usuario>@<kit01> sudo systemctl start backup.service
ssh <usuario>@<kit01> 'journalctl -u backup.service --since -10min -o cat | grep -E "saved|no errors"'
```

Deben aparecer cuatro líneas `snapshot ... saved` (configuración, recursos, bases de datos y dominio) y `no errors were found`.

## Paso 3. Instantánea de las VMs

```bash
cd platform/ansible
ansible-playbook playbooks/actualizacion.yml -e paso=instantanea
```

Apaga `comunidad01`, le saca una instantánea de sus dos discos, la enciende y espera a que todas sus sondas estén en verde. Después hace lo mismo con `clinica01`. La VM se apaga por ACPI y nunca se fuerza, así que PostgreSQL y el directorio quedan cerrados limpios dentro de la instantánea. La instantánea se llama `antes-<fecha>` y, si ya existe una con ese nombre, el paso no hace nada.

| Comprobación | Esperado |
|---|---|
| `virsh -c qemu:///system snapshot-list clinica01` (en kit01) | `antes-<fecha>` |
| `virsh -c qemu:///system snapshot-list comunidad01` | `antes-<fecha>` |
| El playbook | `en verde a los ... s` para cada VM y ninguna falla |

## Paso 4. Paquetes de las VMs

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=paquetes
```

En cada VM, una después de la otra, actualiza los paquetes sin los retenidos, comprueba que lo que queda pendiente es solo lo retenido, baja las imágenes de las versiones fijadas (las que se construyen en la VM se omiten) y reinicia la VM si la actualización lo pide. Al final espera a que todas sus sondas estén en verde.

| Comprobación | Esperado |
|---|---|
| `apt list --upgradable` en cada VM | Vacío o solo paquetes retenidos |
| `docker ps` en cada VM | Todos los contenedores `Up`, con `healthy` los que tienen chequeo |
| `./scripts/P12-reinicio.sh estado` | Sin fallas |
| `ansible-playbook playbooks/verificar-flujos.yml` | Todos los flujos como se esperaba |

Si algo quedó mal en una VM, se vuelve a la instantánea.

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=revertir -e vms=clinica01
```

## Paso 5. Paquetes de kit01

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=paquetes-kit01
```

Actualiza kit01 sin los retenidos y sin reiniciar. kit01 no tiene instantánea, por eso va después de las VMs y solo con lo que no toca la red ni el acceso remoto. Si llega un kernel nuevo, queda instalado y se activa en el próximo reinicio, que se hace con alguien en el sitio.

| Comprobación | Esperado |
|---|---|
| `apt list --upgradable` en kit01 | Solo los retenidos y los que dependen de la versión exacta de uno de ellos (con BIND9 retenido quedan sus bibliotecas y utilidades, que el playbook informa aparte) |
| `netbird status` | `Management: Connected` |
| `sudo nft list ruleset \| grep -c chain` | El mismo número que antes |
| `./scripts/P12-reinicio.sh estado` | Sin fallas |

## Paso 6. Imágenes al disco USB

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=imagenes
```

Monta el disco USB en kit01 como lo hace la copia y, por cada VM, guarda todas sus imágenes con `docker save`, comprimidas, en `imagenes/<vm>/` del disco, con la lista de imágenes y sus sha256. Para mover los archivos crea una llave temporal en kit01 que la VM acepta solo desde kit01 y sin terminal. Al terminar, aunque algo falle, quita la llave de la VM, la borra de kit01 y desmonta el disco. Cada vez reemplaza el juego anterior, así que en el disco queda solo el último.

| Comprobación | Esperado |
|---|---|
| El playbook | `sha256 bien` para cada VM y la lista de sus imágenes |
| `findmnt /mnt/backup` en kit01 | Nada (el disco quedó desmontado) |

Las imágenes que se construyen en la VM (la consulta de prerregistros y el formulario) también se guardan, porque construirlas otra vez necesita Internet.

## Paso 7. Borrar las instantáneas

Cuando todo está verificado, se borran las instantáneas. Ocupan espacio dentro del disco de cada VM y crecen con cada cambio, y la copia del paso 2 queda en el disco USB.

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=borrar
```

## Reinstalar una imagen sin Internet

Si una imagen se daña o se borra en campo, se carga desde el disco USB conectado a kit01 y después se levanta el servicio.

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=cargar -e vms=comunidad01 -e imagen=ghcr.io/kiwix/kiwix-serve:3.8.2
ssh -J <usuario>@<kit01> <usuario>@10.20.20.12 'cd /srv/kiwix && sudo docker compose up -d'
```

El paso comprueba el sha256 del archivo en el disco, lo copia a la VM, lo carga con `docker load` y muestra el identificador de la imagen, que es el mismo que tenía antes de borrarse. La carpeta de cada servicio está en `/srv/<servicio>` de su VM.

## Cambiar la versión de una imagen

Una versión nueva de una aplicación se prueba como cualquier cambio del kit, en una rama y con su prueba, y solo después se aplica.

1. Cambiar la versión en el `compose.yml` del servicio, en el repositorio `apps`.
2. Leer las notas de la versión nueva, sobre todo si cambia la base de datos (DHIS2 y PostgreSQL migran sus datos al arrancar y no vuelven atrás solos).
3. Hacer los pasos 1 a 3 de este procedimiento.
4. Aplicar el playbook de la VM (`playbooks/clinica01.yml` o `playbooks/comunidad01.yml`), que baja la imagen nueva y recrea el contenedor.
5. Revisar el estado, los flujos y la prueba del servicio. Si falla, volver a la instantánea.
6. Hacer los pasos 6 y 7.

## Actualizar un paquete retenido

```bash
sudo apt-mark unhold <paquete>
sudo apt-get install --only-upgrade <paquete>
sudo apt-mark hold <paquete>
```

Antes, la instantánea si el paquete está en una VM. Después, la prueba del servicio y el estado del kit. En kit01, los paquetes de la red, el firewall y NetBird se actualizan solo con alguien en el sitio, porque un error corta el acceso remoto.

## Si algo falla

- **Una VM no se apaga en 3 minutos.** El paso se detiene sin forzarla. Revisar qué la retiene con `virsh -c qemu:///system console <vm>` o entrando por SSH, y repetir.
- **Una VM no vuelve a verde después de actualizar.** `ansible-playbook playbooks/actualizacion.yml -e paso=revertir -e vms=<vm>` la deja como estaba antes del paso 3.
- **`/mnt/backup ya está montado`.** Quedó montado de una consulta manual. Se desmonta con `sudo umount /mnt/backup` en kit01 y se repite.
- **El disco USB no está conectado.** El paso de imágenes falla al montar y no deja nada a medias. La copia programada del domingo también lo avisa.

## Tiempos medidos

Medidos en el kit, con todo en verde antes y después.

| Paso | Tiempo | Detalle |
|---|---|---|
| Copia al disco USB | 16 s | Cuatro copias guardadas y el repositorio sin errores |
| Instantánea de las dos VMs | 1 min 38 s | `comunidad01` en verde a los 20 s de responder su SSH y `clinica01` a los 40 s |
| Paquetes de las VMs | 2 min 5 s | 16 paquetes en `clinica01` (con `containerd`, sin cortar los contenedores) y 15 en `comunidad01`; no pidieron reinicio; ninguna imagen cambió |
| Paquetes de kit01 | 45 s | 14 paquetes; el firewall, las reglas de NetBird y su conexión quedaron iguales |
| Imágenes al disco USB | 2 min 6 s | 8 imágenes, 1,5 GB comprimidas (5,2 GB sin comprimir), sha256 bien |
| Reinstalar una imagen sin Internet | 43 s | `kiwix-serve` volvió con el mismo identificador; la biblioteca estuvo fuera 1 min 40 s, desde que se detuvo hasta que se levantó |
