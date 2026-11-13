<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Guía de operación y plan de respaldo

**Proyecto final - Plataformas I - 2026-2** · Organización `kitsalud-movil-plats1`

Este documento junta la **guía de operación (E3)** y el **plan de respaldo y recuperación (E5)**. Van juntos porque los hace la misma persona y casi siempre en el mismo momento. Cerrar una misión, por ejemplo, es sacar una copia y después apagar el kit.

Está pensado para el personal técnico de la brigada, es decir, para quien tiene el usuario de administración del kit aunque no lo haya instalado. Cada procedimiento dice qué hacer y cómo saber si funcionó. La instalación desde cero y las reglas del firewall están en el documento de arquitectura, despliegue y seguridad (E1, E2 y E4).

<div class="salto"></div>

# Parte 1. Guía de operación (E3)

## 1. Antes de empezar

El kit tiene tres equipos con sistema. **kit01** es el mini PC que hace de router, firewall, DNS, DHCP y hora, y donde corren las dos máquinas virtuales. **clinica01** tiene la historia clínica, el dominio de usuarios y los archivos del personal. **comunidad01** tiene la biblioteca, los videos y el formulario de prerregistro.

| Equipo | Dirección |
|---|---|
| kit01 | `10.20.10.1` desde la red Interna, `100.90.225.113` por NetBird |
| clinica01 | `10.20.20.11` |
| comunidad01 | `10.20.20.12` |
| sw01 (switch) | `10.20.10.2` |
| ap01 (Wi-Fi) | `10.20.10.3`, por su página web |

| Servicio | Dirección |
|---|---|
| Historia clínica (DHIS2) | `https://pacientes.salud.movil` |
| Consulta de prerregistros | `https://consultas.salud.movil` |
| Archivos compartidos | `\\archivos.salud.movil\archivos` y `\\archivos.salud.movil\contenido` |
| Monitoreo (Grafana) | `https://monitoreo.salud.movil` |
| Biblioteca y videos | `http://biblioteca.salud.movil` y `http://videos.salud.movil` |
| Formulario de prerregistro | `https://registro.salud.movil` |

Para administrar, el equipo tiene que estar conectado por cable al puerto `ether4` del switch, donde recibe una dirección de administración, o entrar por NetBird cuando hay Internet. Desde otro puerto o desde el Wi-Fi, kit01 rechaza el SSH a propósito. Las VMs solo aceptan SSH desde kit01, así que a ellas se llega saltando.

```bash
ssh kitsalud@10.20.10.1                              # kit01
ssh -J kitsalud@10.20.10.1 kitsalud@10.20.20.11      # clinica01
ssh -J kitsalud@10.20.10.1 kitsalud@10.20.20.12      # comunidad01
```

Las contraseñas no están en este documento. Están en el vault de Ansible y en la hoja privada del grupo.

## 2. Inicio

1. Conectar a la corriente el switch y el punto de acceso, y esperar a que se enciendan los indicadores de sus puertos.
2. Encender kit01 con su botón.
3. Esperar unos 3 minutos. kit01 levanta solo la red, el firewall, el DHCP, el DNS, la hora, los logs, el portal y el monitoreo, y después enciende las dos VMs. Cada aplicación espera a la base de datos y al dominio, así que no hay que arrancar nada a mano.

<div class="diagrama"><img src="../diagramas/encendido-apagado.png" alt="Encendido y apagado del kit"></div>

Para comprobar que arrancó bien, en kit01.

```bash
systemctl --failed                          # 0 loaded units listed
virsh -c qemu:///system list --all          # clinica01 y comunidad01 en running
```

En el navegador, el tablero **Estado del kit** de `https://monitoreo.salud.movil` muestra **Problemas ahora** en 0. Si una VM sigue apagada después de 5 minutos, se enciende con `sudo virsh -c qemu:///system start <vm>`. `virsh` siempre necesita `-c qemu:///system`, porque sin eso consulta las máquinas del propio usuario y la lista sale vacía.

## 3. Apagado

El apagado ordenado cierra primero lo que tiene datos, para que la base de datos y el dominio terminen limpios.

1. Si se cierra una misión, sacar antes una copia con el disco USB conectado (sección 12).
2. En kit01, ejecutar el apagado ordenado.

   ```bash
   sudo kit-apagado
   ```

   Apaga comunidad01, después clinica01 y al final kit01. Cada VM tiene hasta 180 segundos para cerrar y, si no termina, se fuerza para que kit01 alcance a apagarse.
3. Cuando el indicador de kit01 se apaga, desconectar el switch y el punto de acceso.

No se usa `shutdown` ni `poweroff`, porque apagan las dos VMs al mismo tiempo y sin orden. Si al encender otra vez se quiere ver cómo terminó el apagado anterior, `journalctl -t kit-apagado -b -1` muestra cada paso con su hora.

### 3.1 Corte de energía

El kit no tiene una UPS física. Su estado se simula con NUT, y cuando la batería queda baja la UPS lógica ejecuta el mismo `kit-apagado`. Estos comandos permiten probarlo.

| Comando | Qué simula | Qué hace el kit |
|---|---|---|
| `sudo kit-ups` | Nada | Muestra el estado de la UPS |
| `sudo kit-ups ob` | Se cortó la energía | Avisa en el journal y no apaga nada |
| `sudo kit-ups lb` | La batería quedó baja | Ejecuta el apagado ordenado |
| `sudo kit-ups ol` | Volvió la energía | Vuelve al estado normal |

Cuando se conecte una UPS real por USB, se espera que funcione igual cambiando solo el driver de NUT. En `platform/ansible/roles/nut/templates/ups.conf.j2` se cambia `driver = dummy-ups` por `driver = usbhid-ups` y se aplica `ansible-playbook playbooks/nut.yml`. El apagado ordenado no cambia. Esto no se ha probado con una UPS física, así que lo primero es simular un corte con la UPS conectada y medir cuánto dura la batería.

## 4. Revisión rápida (health check)

Esta revisión dice en pocos minutos si el kit está bien y, si algo falla, por dónde empezar. Se hace al comenzar cada jornada y cada vez que alguien reporta un problema.

**Paso 1. El tablero.** `https://monitoreo.salud.movil` abre en **Estado del kit**. Se entra con una cuenta del grupo `admins` del dominio, o con la cuenta local `admin` de Grafana si el dominio no responde. Lo normal es **Problemas ahora** en 0, todos los equipos encendidos y todos los servicios en verde. Si algo está en rojo, la tabla **Qué está fallando** dice qué servicio, en qué equipo y si falla en IPv4 o en IPv6. Cada servicio se prueba cada 15 segundos y se pone en rojo cuando lleva 30 segundos fallando.

**Paso 2. kit01 en un minuto.**

```bash
systemctl --failed                          # servicios caídos
virsh -c qemu:///system list --all          # las dos VMs en running
df -h / /var/lib/libvirt/images             # por debajo del 80 %
chronyc tracking | grep "Leap status"       # Normal
```

**Paso 3. Buscar por síntoma.** Después de arreglar, se vuelve al tablero y se espera a que todo esté en verde.

| Síntoma | Dónde | Revisar | Arreglar |
|---|---|---|---|
| Nada de una VM responde | kit01 | `virsh -c qemu:///system list --all` | `sudo virsh -c qemu:///system start <vm>` |
| Los equipos no resuelven nombres | kit01 | `dig @10.20.20.10 pacientes.salud.movil` | `sudo systemctl restart named`. Si no arranca, `sudo named-checkconf` dice qué archivo tiene el error |
| Los equipos nuevos no reciben dirección | kit01 | `systemctl status kea-dhcp4-server` y `ip link show enp171s0` | `sudo systemctl restart kea-dhcp4-server kea-dhcp6-server radvd`. Si `enp171s0` no tiene enlace, revisar el cable al puerto 1 del switch y reiniciar Kea cuando vuelva |
| DHIS2 o la base de datos en rojo | clinica01 | `cd /srv/dhis2 && sudo docker compose ps` | `sudo docker compose up -d`. DHIS2 tarda cerca de un minuto en responder |
| Nadie entra con su usuario, o los archivos en rojo | clinica01 | `systemctl status samba-ad-dc` | `sudo systemctl restart samba-ad-dc` |
| Biblioteca, videos o registro en rojo | comunidad01 | `sudo docker ps -a` | En la carpeta del servicio caído, dentro de `/srv`, `sudo docker compose up -d` |
| Los celulares de la Comunidad no ven el portal | kit01 | `systemctl status nginx kitsalud-portal` | `sudo systemctl restart nginx kitsalud-portal`, y en el celular abrir una dirección con `http://` |
| Alguien no llega a un servicio que debería ver | kit01 | `sudo tail -20 /var/log/kitsalud/kit01/firewall.log` | Si el bloqueo es correcto, como un celular de la Comunidad que intenta abrir DHIS2, no hay nada que hacer |
| La copia de la semana falló | kit01 | `journalctl -u backup -o cat \| tail -20` y `lsblk -f` | Conectar el disco USB y sacar la copia a mano (sección 12) |

Si un problema se repite, se anota la hora, el síntoma y lo que mostraron los comandos, porque con eso se busca en los logs (sección 6).

## 5. Gestión de usuarios

El kit tiene dos tipos de cuentas personales. Las **del dominio** sirven para los archivos compartidos, la consulta de prerregistros y el monitoreo, y las **de DHIS2** para la historia clínica. Son independientes, aunque cada persona usa el mismo nombre en las dos (por ejemplo `ana.rojas`). DHIS2 tiene sus propias cuentas para que el registro de pacientes siga funcionando si el dominio falla.

| Grupo del dominio | A qué entra |
|---|---|
| `clinicos` (gid 10001) | Recurso `archivos`, recurso `contenido` y consulta de prerregistros |
| `admins` (gid 10002) | Recurso `contenido` y monitoreo (Grafana) |

### 5.1 Usuarios del dominio, en clinica01

Estos son los comandos para gestionar las cuentas directamente en clinica01, sin la máquina de control.

| Qué | Comando |
|---|---|
| Ver las cuentas y un grupo | `sudo samba-tool user list` y `sudo samba-tool group listmembers clinicos` |
| Crear una cuenta (pide la contraseña) | `sudo samba-tool user create maria.lopez --given-name=Maria --surname=Lopez` |
| Darle su número de usuario y su grupo principal | `sudo samba-tool user addunixattrs maria.lopez 10104 --gid-number=10001` |
| Agregarla a un grupo | `sudo samba-tool group addmembers clinicos maria.lopez && sudo net cache flush` |
| Quitarla de un grupo | `sudo samba-tool group removemembers clinicos maria.lopez && sudo net cache flush` |
| Cambiar la contraseña | `sudo samba-tool user setpassword maria.lopez` |
| Deshabilitar o habilitar | `sudo samba-tool user disable maria.lopez` y `sudo samba-tool user enable maria.lopez` |
| Desbloquear | `sudo samba-tool user unlock maria.lopez` |
| Borrar | `sudo samba-tool user delete maria.lopez` |

El número de usuario (`uid`) se toma libre desde 10101. Después de 5 contraseñas equivocadas la cuenta se bloquea 15 minutos. Después de cambiar una contraseña, la anterior sigue sirviendo hasta una hora en los recursos compartidos, así que para cortar el acceso de inmediato se deshabilita la cuenta.

### 5.2 Personas permanentes, con Ansible

Una persona que va a estar en todas las misiones se agrega también al inventario de Ansible, con el mismo `uid`. Así, si el dominio se reconstruye, la cuenta vuelve igual y sus archivos conservan el dueño. Desde la máquina de control, en `platform/ansible`, se agrega la persona en `inventarios/kit/group_vars/all/samba.yml` y en `dhis2.yml`, y se aplica.

```yaml
- { nombre: maria.lopez, nombres: Maria, apellidos: Lopez, uid: 10104, grupos: [clinicos] }
```

```bash
ansible-playbook playbooks/samba.yml
ansible-playbook playbooks/clinica01.yml
```

Los playbooks solo crean lo que falta. No cambian contraseñas ni borran cuentas, y eso se hace con los comandos de la sección 5.1.

### 5.3 Cuentas de DHIS2

En `https://pacientes.salud.movil`, con una cuenta de rol "Administrador", se abre la app **Users**. Al crear una cuenta se le pone el rol "Personal clínico", la unidad del kit en las tres listas de **Organisation units** y el grupo "Personal clínico". Sin el grupo, la persona entra pero no ve los pacientes. Para quitar el acceso se usa **Disable** y no **Delete**, así queda claro quién hizo cada registro.

### 5.4 Administración del kit

Es un solo usuario con `sudo` en kit01 y en las dos VMs. Para cambiar su contraseña se ejecuta `passwd` en los tres equipos y después se actualizan en el vault `vault_admin_password` y su hash (`mkpasswd -m sha-512`) con `ansible-vault edit`. Si no se actualiza el vault, Ansible deja de poder conectarse.

## 6. Revisión de logs

Todos los equipos envían sus logs a kit01, a una carpeta por equipo en `/var/log/kitsalud/`. Por eso los logs de una VM se pueden leer aunque esa VM esté apagada.

| Archivo en kit01 | Qué tiene |
|---|---|
| `/var/log/kitsalud/<equipo>/auth.log` | Inicios de sesión SSH, `sudo` y, en clinica01, los inicios de sesión del dominio |
| `/var/log/kitsalud/<equipo>/syslog.log` | Todo lo demás de cada equipo, incluido el switch |
| `/var/log/kitsalud/kit01/firewall.log` | Lo que bloqueó el firewall |
| `/var/log/kitsalud/kit01/dhcp.log` | Direcciones entregadas |
| `/var/log/named/consultas.log` | Cada consulta al DNS del kit |

```bash
# Inicios de sesión SSH fallidos
sudo grep -h -E "Failed password|Invalid user" /var/log/kitsalud/*/auth.log | tail
# Inicios de sesión del dominio con problemas
sudo grep samba-auth /var/log/kitsalud/clinica01/auth.log | grep -E "WRONG_PASSWORD|LOCKED_OUT|NO_SUCH_USER" | tail
# Bloqueos del firewall, contados por tipo
sudo grep -o "fw-drop [A-Za-z0-9-]*" /var/log/kitsalud/kit01/firewall.log | sort | uniq -c | sort -rn
# Direcciones entregadas por el DHCP
sudo grep DHCP4_LEASE_ALLOC /var/log/kitsalud/kit01/dhcp.log | tail
# Un servicio o una aplicación concreta
journalctl -u <servicio> --since -15min
cd /srv/dhis2 && sudo docker compose logs --since 15m core
```

En el log del firewall, `fw-drop F-20` es algo de la Comunidad que intentó llegar a la red clínica o a la gestión, `fw-drop F-21` es un SSH desde un equipo que no es de administración y `fw-drop br-srv` es una VM que intentó llegar a la otra. En cada línea, `IN` es la red de origen (`br-com` la Comunidad, `lan0.10` la Interna, `br-srv` los servidores), `SRC` y `DST` las direcciones y `DPT` el puerto. Las líneas con `IN=enp170s0` son difusiones normales de la red del sitio y no son ataques.

Los logs rotan cada semana y se guardan cuatro copias comprimidas, que se leen con `zgrep`.

## 7. Actualización

Las actualizaciones se hacen en la base, con Internet y en una ventana de mantenimiento, nunca en campo. Antes de tocar nada se saca una copia al disco USB y una instantánea de cada VM, así que si algo sale mal en una VM se vuelve atrás. Todo toma unos 7 minutos.

Los servicios del kit cuya configuración depende de la versión (BIND9, Kea, Chrony, nginx, Samba, Docker y otros) están retenidos con `apt-mark hold` y no se actualizan con este procedimiento. Las imágenes de Docker tienen su versión escrita en cada `compose.yml`, así que tampoco cambian solas.

Todo se ejecuta desde la máquina de control, en `platform/ansible`, en este orden.

```bash
# 1. Copia al disco USB (debe terminar en success)
ansible kit01 -b -m shell -a 'systemctl start backup.service; systemctl show -p Result --value backup.service'
# 2. Instantánea de cada VM (las apaga, les saca la instantánea y las enciende)
ansible-playbook playbooks/actualizacion.yml -e paso=instantanea
# 3. Paquetes de las VMs, una por una, y reinicio si lo piden
ansible-playbook playbooks/actualizacion.yml -e paso=paquetes
# 4. Paquetes de kit01, sin reiniciar y sin tocar la red ni NetBird
ansible-playbook playbooks/actualizacion.yml -e paso=paquetes-kit01
# 5. Guardar las imágenes de Docker en el disco USB, para reinstalarlas sin Internet
ansible-playbook playbooks/actualizacion.yml -e paso=imagenes
# 6. Cuando todo está verificado, borrar las instantáneas
ansible-playbook playbooks/actualizacion.yml -e paso=borrar
```

Después de los pasos 3 y 4 se revisa que el tablero siga en verde y que `ansible-playbook playbooks/verificar-flujos.yml` termine con todos los flujos como se esperaba.

Si una VM quedó mal, se vuelve a su instantánea.

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=revertir -e vms=clinica01
```

Si en campo se daña una imagen de Docker, se carga desde el disco USB sin Internet y se levanta el servicio.

```bash
ansible-playbook playbooks/actualizacion.yml -e paso=cargar -e vms=comunidad01 -e imagen=ghcr.io/kiwix/kiwix-serve:3.8.2
ssh -J kitsalud@10.20.10.1 kitsalud@10.20.20.12 'cd /srv/kiwix && sudo docker compose up -d'
```

Un paquete retenido se actualiza solo a propósito y de a uno, con `sudo apt-mark unhold <paquete>`, `sudo apt-get install --only-upgrade <paquete>` y `sudo apt-mark hold <paquete>`. Los de la red, el firewall y NetBird en kit01 se actualizan solo con alguien en el sitio, porque un error corta el acceso remoto.

## 8. Operación sin Internet

El kit está hecho para trabajar sin Internet, así que un sitio sin conexión, o una conexión que se cae a mitad de la jornada, no detiene la atención.

| Sigue funcionando | Deja de funcionar |
|---|---|
| DHCP, DNS de `salud.movil` y hora | Navegar por Internet |
| Historia clínica, consulta de prerregistros y archivos | Los nombres de Internet |
| Biblioteca, videos y formulario de prerregistro | La administración remota por NetBird |
| Portal cautivo, que el celular abre solo | Las actualizaciones |
| Inicio de sesión del dominio y de DHIS2, monitoreo, logs y copias | |

Sin Internet, kit01 lo detecta en menos de un minuto y hace que a los celulares de la Comunidad cualquier nombre externo los lleve al portal. Así el celular abre el portal solo. Cuando vuelve Internet todo regresa solo, y no hay que hacer nada.

Para saber si el kit tiene Internet, en kit01.

```bash
cat /run/kit-internet/modo        # con o sin
ping -c 3 1.1.1.1                 # 0% packet loss con Internet
```

Sin NetBird, el kit se administra desde un equipo conectado al puerto `ether4` del switch, con la red en automático. Si no recibe dirección, se le pone a mano `10.20.10.29/24`, con puerta de enlace `10.20.10.1` y DNS `10.20.20.10`. Desde ahí el acceso es el de la sección 1.

## 9. Perfiles por misión

El mismo kit sirve para misiones distintas, y según la misión se enciende o no cada VM. kit01 siempre está encendido, y el direccionamiento, el DNS y el firewall no cambian entre perfiles.

<div class="diagrama-fisico"><img src="../diagramas/perfiles-mision.png" alt="Perfiles por misión"></div>

Para apagar una VM de forma que no vuelva a encender sola, en kit01.

```bash
sudo virsh -c qemu:///system autostart --disable <vm>
sudo virsh -c qemu:///system shutdown <vm>
```

Para volver al perfil de referencia.

```bash
sudo virsh -c qemu:///system autostart <vm>
sudo virsh -c qemu:///system start <vm>
```

Hay dos ajustes según el perfil. En **Solo clínica** se detiene en clinica01 la publicación de contenido, que copia material a comunidad01 cada 10 minutos y fallaría con ella apagada (`sudo systemctl disable --now publicacion.timer`, y `enable --now` al volver), y se desactiva el SSID de la Comunidad en la página del AP. En **Jornada comunitaria** no hay historia clínica ni prerregistro, y a Grafana se entra con la cuenta local `admin`, porque el dominio está en clinica01.

Con una VM apagada, el tablero la muestra en rojo y la copia del domingo termina con error porque no puede extraer de ella, aunque guarda lo demás. En estos perfiles es lo esperado.

<div class="salto"></div>

# Parte 2. Plan de respaldo y recuperación (E5)

## 10. Resumen del plan

| Elemento | Definición |
|---|---|
| Qué se respalda | Las bases de datos de DHIS2 y de prerregistros, el dominio de Samba AD, los recursos `archivos` y `contenido`, y la configuración de los tres equipos |
| Método | restic en modo extracción. kit01 saca los datos de cada VM por SSH y los guarda cifrados en un disco USB. Las VMs no tienen la clave de las copias |
| Frecuencia | Cada domingo a las 4:00, y una copia manual antes de cada cambio y al cerrar cada misión |
| Retención | 4 copias semanales y 3 mensuales |
| Destino | Disco USB de 500 GB conectado a kit01, montado solo durante la copia |
| Pérdida máxima | Una semana de datos, o menos con la copia manual |

## 11. Qué se respalda

| Etiqueta | Qué tiene | De dónde |
|---|---|---|
| `bd` | Volcado (`pg_dump`) de las bases `dhis2` y `prerregistro` y los roles de PostgreSQL | clinica01 |
| `dominio` | Respaldo del dominio con `samba-tool domain backup offline` | clinica01 |
| `recursos` | Recursos `archivos` y `contenido`, con dueños, permisos y ACL | clinica01 |
| `config` | `/etc` de kit01, con la raíz de la CA, y `/etc` y `/srv` de las VMs sin datos grandes | kit01 y las dos VMs |

No se respaldan los discos de las VMs, porque se reconstruyen con Ansible y después se restauran los datos. Tampoco las imágenes de Docker, que tienen versión fija y se descargan otra vez, ni los videos de comunidad01, que son una copia de `contenido`, ni los logs, que son de diagnóstico.

## 12. Cómo funciona la copia

kit01 entra a cada VM con el usuario `backup`, cuya llave solo se acepta desde kit01 y solo puede ejecutar el comando de extracción. Junta todo en un área temporal, guarda un snapshot de restic por etiqueta, borra los que pasan de la retención y termina con `restic check`. El disco se monta por su UUID solo mientras dura la copia y se desmonta al terminar, aunque algo falle. El repositorio está cifrado con una clave que solo tiene kit01 (y el vault de Ansible), así que sin ella no se puede leer. Si kit01 estaba apagado el domingo, la copia corre al encenderlo.

<div class="diagrama"><img src="../diagramas/flujo-respaldo.png" alt="Respaldo semanal en modo pull"></div>

Para sacar una copia a mano, con el disco USB conectado, en kit01. Tarda unos 15 segundos.

```bash
sudo systemctl start backup.service
systemctl show -p Result --value backup.service               # success
journalctl -u backup.service --since -5min -o cat | grep -E "saved|no errors"
```

Deben aparecer cuatro líneas `snapshot ... saved` y `no errors were found`. Si la copia falla, el tablero muestra **UnidadFallida** de kit01, y casi siempre es porque el disco no está conectado (`lsblk -f` debe mostrar `kitbackup`).

## 13. Restauración

Toda restauración empieza en kit01, como root, con el disco montado.

```bash
sudo -i
mount -o noatime,nodev,nosuid,noexec UUID=<uuid del disco kitbackup> /mnt/backup
export RESTIC_REPOSITORY=/mnt/backup/restic RESTIC_PASSWORD_FILE=/etc/kitsalud/backup/restic.clave RESTIC_CACHE_DIR=/var/cache/restic
S=/var/lib/kitsalud/backup
restic snapshots                     # fechas y etiquetas de las copias
# ... restauración ...
umount /mnt/backup                   # siempre al terminar
```

Lo restaurado se pasa a la VM desde kit01. Para recuperar una copia anterior se usa el ID de un snapshot en lugar de `latest`.

| Qué se perdió | Tiempo aproximado |
|---|---|
| Un archivo o una tabla | Unos 70 segundos |
| La base `dhis2` completa | Menos de 5 minutos |
| El dominio | De 15 a 30 minutos |
| Una VM completa | De 1 a 2 horas, en la base y con Internet |
| kit01 completo | Medio día, en la base y con Internet |

### 13.1 Un archivo de los recursos

```bash
restic restore latest --tag recursos --include $S/clinica01/archivos/<ruta> --target /tmp/r
```

En clinica01 se copia a `/srv/samba/archivos/` con `sudo cp`, sin `-a`, y después `sudo chown` y `sudo chmod` con el dueño y los permisos que tenía. Así el archivo hereda la ACL del recurso y queda igual que antes. Con `cp -a` o con `install` la ACL no se hereda.

### 13.2 Una tabla o una base de datos

```bash
restic dump latest --tag bd $S/clinica01/postgres/<base>.dump > /tmp/<base>.dump
```

En clinica01, una tabla se restaura con `sudo docker exec -i dhis2-db-1 pg_restore -U dhis -d <base> -t <tabla> < <base>.dump`. La base `dhis2` completa se restaura con DHIS2 detenido, para que no escriba mientras se carga.

```bash
cd /srv/dhis2 && sudo docker compose stop core
sudo docker exec -i dhis2-db-1 pg_restore -U dhis -d dhis2 --clean --if-exists < dhis2.dump
sudo docker compose start core
```

### 13.3 Una configuración

`restic restore latest --tag config --include <ruta> --target /tmp/r`. Lo que instala Ansible se recupera mejor ejecutando otra vez su playbook, y la copia sirve para comparar o para lo que se cambió a mano.

### 13.4 El dominio

Lo normal es aprovisionarlo otra vez con `ansible-playbook playbooks/samba.yml`, que crea los mismos grupos y usuarios con los mismos números, así que los archivos restaurados conservan sus dueños. Se pierden las contraseñas que los usuarios hayan cambiado. Si hay cambios hechos a mano que se deben conservar, se restaura el respaldo del dominio con `samba-tool domain backup restore`, que exige un nombre de controlador nuevo (`dc02`). Después se agregan otra vez los registros DNS de `dc01` y se ejecuta `samba.yml` para que el resto del kit siga usando el mismo nombre.

### 13.5 Una VM o kit01 completo

Una VM se recrea con `playbooks/vms.yml`, se le aplica su playbook (`clinica01.yml` y `samba.yml`, o `comunidad01.yml`), después `publicacion.yml` y `backups.yml`, y al final se restauran sus datos con las secciones anteriores. comunidad01 no tiene datos propios.

Para kit01, se instala Ubuntu Server 24.04 y NetBird, se restaura primero la raíz de la CA (`/etc/kitsalud/ca`) desde el snapshot `config`, para que los certificados que ya tienen los equipos sigan valiendo, y después se aplican los playbooks en el orden del despliegue y se recuperan las VMs. Las dos cosas necesitan Internet, así que se hacen en la base.

### 13.6 Si el disco falla o se pierde la clave

Si el disco falla, los datos vivos no se tocan, solo se pierden las copias. Se formatea otro disco con la etiqueta `kitbackup`, se cambia `backup_disco_uuid` en el inventario y se ejecuta `backups.yml`. La siguiente copia crea el repositorio. Si se pierde la clave, las copias no se pueden leer de ninguna forma, y por eso se guarda en kit01 y en el vault de Ansible.

## 14. Verificación periódica

Una copia que nunca se restauró no da garantías, así que el plan incluye restaurar de verdad cada cierto tiempo.

| Qué | Cuándo | Cómo |
|---|---|---|
| Que la copia corrió | Cada semana | El tablero sin **UnidadFallida** y `systemctl list-timers backup.timer` |
| Restaurar un archivo y una tabla | Cada mes | Script `docs/pruebas/scripts/P11-restauracion.sh` desde la máquina de control |
| Restaurar la base y el dominio completos | Antes de cada salida a campo | En una base y un directorio temporales, comparándolos con lo vivo |

## 15. Límites

- Hoy hay una sola copia y viaja con el kit, así que un robo o un incendio se llevan los datos y la copia a la vez. Lo que lo resolvería es un segundo disco que se queda en la base o una copia en línea a un servidor de la organización de salud.
- Lo registrado entre dos copias se pierde si falla el disco de kit01 antes de la siguiente. La copia manual al cerrar cada misión reduce esa ventana.
- Reconstruir una VM o kit01 necesita Internet, así que en campo solo se restauran datos sobre equipos que funcionan.
