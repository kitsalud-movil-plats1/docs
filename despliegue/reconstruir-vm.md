# Reconstruir una máquina virtual

Esta parte vuelve a crear una VM desde cero cuando su disco se dañó, cuando se borró por error o cuando conviene empezar limpia. La VM nueva queda igual que la anterior, con el mismo nombre, la misma MAC y las mismas direcciones, así que el firewall, el DNS, el monitoreo y los demás equipos no cambian. Se hace en la base, con Internet, porque se descargan paquetes, imágenes de contenedores y el contenido de la biblioteca y los videos.

| VM | Qué se pierde al reconstruirla | De dónde vuelve |
|---|---|---|
| comunidad01 | Nada propio. Su configuración sale de Ansible, la biblioteca llega con la publicación desde clinica01 y los videos los descarga su rol | Ansible y la publicación |
| clinica01 | Los pacientes de DHIS2, los prerregistros, los archivos de los recursos SMB y lo que se haya cambiado en el dominio fuera de Ansible | La última copia de restic (sección clinica01) |
| prueba01 | Nada. Es un cliente de pruebas | Ansible |

## Antes de empezar

1. **Copia manual**, si la VM todavía arranca. Con el disco USB conectado a kit01.

   ```bash
   ansible kit01 -b -m shell -a 'systemctl start backup.service; systemctl show -p Result --value backup.service'   # success
   ```

2. **Quitar la VM anterior.** Hay dos formas, y en las dos el nombre queda libre para crearla de nuevo. Los comandos van en kit01 (`ssh kitsalud@<ip-netbird-de-kit01>`), con `<vm>` igual a `comunidad01`, `clinica01` o `prueba01`.

   **Con vuelta atrás** (recomendada si la VM todavía funciona). Se apaga, se guarda su definición y se apartan sus discos con otro nombre. Si la reconstrucción falla, la VM anterior vuelve en un minuto.

   ```bash
   sudo virsh shutdown <vm>; until [ "$(sudo virsh domstate <vm>)" = "shut off" ]; do sleep 2; done
   sudo virsh dumpxml <vm> | sudo tee /root/<vm>.xml >/dev/null
   sudo virsh undefine <vm>
   cd /var/lib/libvirt/images
   for d in <vm>-sistema <vm>-datos; do [ -e $d.qcow2 ] && sudo mv $d.qcow2 $d.qcow2.anterior; done
   ```

   **Sin vuelta atrás**, cuando el disco está dañado o la VM ya no sirve.

   ```bash
   sudo virsh destroy <vm>; sudo virsh undefine <vm> --remove-all-storage
   ```

## comunidad01

Desde `kitsalud/platform/ansible` en la máquina de control, en este orden.

| # | Comando | Qué hace |
|---|---|---|
| 1 | `ansible-playbook playbooks/vms.yml` | Crea la VM que falta con su MAC, sus discos y su red, borra de `known_hosts` la clave de host anterior y le aplica la base común. Las otras VMs no se tocan |
| 2 | `ansible-playbook playbooks/comunidad01.yml` | Docker, la biblioteca, los videos con su contenido, el intermedio de la CA de comunidad01, el formulario de prerregistro y Caddy |
| 3 | `ansible-playbook playbooks/publicacion.yml` | Vuelve a crear el destino de la publicación y actualiza en clinica01 la clave de host de comunidad01 |
| 4 | `ansible-playbook playbooks/backups.yml` | Vuelve a crear el usuario `backup` en la VM y actualiza en kit01 su clave de host |
| 5 | `ansible-playbook playbooks/monitoreo.yml -l kit01,comunidad01` | node_exporter en la VM nueva, con su regla de ufw |

La biblioteca queda vacía hasta la primera publicación, que el timer hace en 10 minutos como máximo. Para no esperar se lanza a mano.

```bash
ansible clinica01 -b -m shell -a 'systemctl start publicacion.service; systemctl show -p Result --value publicacion.service'   # success
```

PENDIENTE resultado de la prueba.

## clinica01

clinica01 tiene los datos del kit, así que después de recrearla se restauran desde la última copia. Los pasos de Ansible son los mismos del despliegue, en este orden.

| # | Comando | Qué hace |
|---|---|---|
| 1 | `ansible-playbook playbooks/vms.yml` | Crea la VM y le aplica la base común |
| 2 | `ansible-playbook playbooks/samba.yml` | Aprovisiona otra vez el dominio con sus grupos, sus usuarios y sus uid y gid fijos, y crea los recursos `archivos` y `contenido` |
| 3 | `ansible-playbook playbooks/clinica01.yml` | DHIS2 con una base nueva, la base de prerregistros, el intermedio de la CA, el certificado LDAPS, la consulta y Caddy |
| 4 | Restaurar los datos (abajo) | Pacientes, prerregistros y archivos |
| 5 | `ansible-playbook playbooks/publicacion.yml` | Origen de la publicación, los archivos de la biblioteca y el timer |
| 6 | `ansible-playbook playbooks/backups.yml` | Usuario `backup` en la VM y su clave de host en kit01 |
| 7 | `ansible-playbook playbooks/monitoreo.yml -l kit01,clinica01` | node_exporter y el acceso de Grafana al dominio |

El dominio se aprovisiona de nuevo con Ansible, porque solo contiene lo que crea Ansible. Como los uid y gid de los usuarios son fijos, los archivos restaurados conservan sus dueños. Se pierden las contraseñas que los usuarios hayan cambiado y las cuentas creadas a mano, que se vuelven a crear.

**Restaurar los datos.** En kit01, como root, con el disco USB conectado.

```bash
sudo -i
mount -o noatime,nodev,nosuid,noexec UUID=<backup_disco_uuid> /mnt/backup
export RESTIC_REPOSITORY=/mnt/backup/restic RESTIC_PASSWORD_FILE=/etc/kitsalud/backup/restic.clave RESTIC_CACHE_DIR=/var/cache/restic
S=/var/lib/kitsalud/backup
restic snapshots                                                       # elegir la copia, por defecto latest
restic dump latest --tag bd $S/clinica01/postgres/dhis2.dump > /tmp/dhis2.dump
restic dump latest --tag bd $S/clinica01/postgres/prerregistro.dump > /tmp/prerregistro.dump
restic restore latest --tag recursos --include $S/clinica01/archivos --target /tmp/r
umount /mnt/backup
scp /tmp/dhis2.dump /tmp/prerregistro.dump kitsalud@10.20.20.11:/tmp/
scp -r /tmp/r$S/clinica01/archivos kitsalud@10.20.20.11:/tmp/archivos
```

En clinica01 (`ssh kitsalud@10.20.20.11` desde kit01), con DHIS2 detenido para que no escriba durante la carga.

```bash
cd /srv/dhis2 && sudo docker compose stop core
sudo docker exec -i dhis2-db-1 pg_restore -U dhis -d dhis2 --clean --if-exists < /tmp/dhis2.dump
sudo docker exec -i dhis2-db-1 pg_restore -U dhis -d prerregistro --clean --if-exists < /tmp/prerregistro.dump
sudo docker compose start core
sudo cp -a /tmp/archivos/. /srv/samba/archivos/
sudo rm -rf /tmp/dhis2.dump /tmp/prerregistro.dump /tmp/archivos
```

Los archivos heredan la ACL por defecto del recurso, así que quedan con los mismos permisos que antes. El recurso `contenido` no hace falta restaurarlo si la publicación ya tenía todo en comunidad01. Si se perdió, se restaura igual que `archivos`. Las tablas analíticas de DHIS2 se regeneran solas a las 2:00.

Estos comandos son los de la prueba de restauración del 2026-11-02 en el kit, donde la base `dhis2` completa volvió con sus 333 tablas y sus 45 893 filas en 7,7 s, una tabla de `prerregistro` volvió con el mismo md5 y un archivo de `archivos` volvió con su dueño del dominio y su ACL. La reconstrucción completa de clinica01 no se hizo en el kit real, porque detiene la historia clínica durante una o dos horas.

## prueba01

```bash
ansible-playbook playbooks/vms.yml
ansible-playbook playbooks/prueba01.yml -e prueba01_estado=apagada
```

prueba01 no lleva la base común ni ufw, porque hace de celular de la Comunidad.

## Si la reconstrucción falla

Con la VM anterior apartada, se borra la nueva y se vuelve a poner la anterior. En kit01, con `<vm>` igual al nombre de la VM.

```bash
sudo virsh destroy <vm>; sudo virsh undefine <vm> --remove-all-storage
cd /var/lib/libvirt/images
for d in <vm>-sistema <vm>-datos; do [ -e $d.qcow2.anterior ] && sudo mv $d.qcow2.anterior $d.qcow2; done
sudo virsh define /root/<vm>.xml && sudo virsh autostart <vm> && sudo virsh start <vm>
```

Desde la máquina de control se borra la clave de host de la VM nueva (`ssh-keygen -R <ip>`) y se ejecutan `publicacion.yml` y `backups.yml`, que vuelven a registrar la clave de la VM anterior.

**Cuando la VM nueva funciona,** se borran la definición y los discos apartados, que ocupan espacio en el volumen de las VMs.

```bash
sudo rm /root/<vm>.xml /var/lib/libvirt/images/<vm>-*.qcow2.anterior
```

## Cómo comprobar que quedó bien

Son las mismas comprobaciones del despliegue, todas en remoto.

```bash
ansible kit01 -m shell -a "curl -s -G --data-urlencode 'query=probe_success == 0 or up == 0' http://127.0.0.1:9090/api/v1/query"   # "result":[]
ansible-playbook playbooks/verificar-flujos.yml                                                                                 # 69 pruebas, todas como se esperaba
ansible kit01 -b -m shell -a 'systemctl start backup.service; systemctl show -p Result --value backup.service'                     # success
ansible kit01 -b -m shell -a 'ls /var/log/kitsalud/<vm>/ && tail -1 /var/log/kitsalud/<vm>/syslog.log'                             # logs recientes de la VM
```
