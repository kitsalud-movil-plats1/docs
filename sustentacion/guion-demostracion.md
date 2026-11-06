<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Guion de sustentación y demostración

**Proyecto final - Plataformas I - 2026-2** · Organización `kitsalud-movil-plats1`

Este guion lleva la demostración de las trece pruebas de aceptación de principio a fin, en vivo y con el kit real. Dice qué equipo usar, cómo entrar a cada servicio, qué comando ejecutar, qué debe verse, qué explicar y qué hacer si algo falla. Sirve igual para la prueba completa previa y para la sustentación. Las contraseñas no están aquí, porque los repositorios no guardan secretos. Están en la hoja privada del grupo.

## 1. Orden y tiempos

| Bloque | Contenido | Tiempo |
|---|---|---|
| Presentación | Problema, arquitectura, decisiones y qué cambiaría con más usuarios | 15 min |
| Comunidad | P5, P1, P4, P3 y P10 | 15 min |
| Clínica | P2, P6, P7 y P8 | 15 min |
| Resiliencia | P11, P13, P12 y P9 | 20 min |
| Preguntas | | 10 min |
| **Total** | | **1 h 15 min** |

P9 va de última a propósito. Al quitar el cable de la WAN se cae NetBird, y los scripts que usan Ansible dejan de funcionar hasta que vuelve.

## 2. Equipos y su papel

| Equipo | Papel | Conexión |
|---|---|---|
| Laptop Fedora | Máquina de control. Ejecuta los scripts del kit y abre Grafana | Cable a `ether4` de sw01, con IP fija `10.20.10.10` |
| Laptop Ubuntu | Estación de la Clínica | Wi-Fi `SaludMovil-Clinica` |
| Laptop Mac | Cliente de la Comunidad | Wi-Fi `SaludMovil-Comunidad` |
| iPhone | Celular de la Comunidad para P5 y P4 | Wi-Fi `SaludMovil-Comunidad` |
| Android | Celular nuevo para ver el portal sin Internet en P9. **No se conecta antes de P9** | Wi-Fi `SaludMovil-Comunidad` |
| Windows, si hay | Abre el recurso `archivos` en P7 | Wi-Fi `SaludMovil-Clinica` |

La laptop Fedora no recibe IPv6 por Wi-Fi, por eso va por cable y P10 se hace en la Mac.

## 3. Accesos y cuentas

| Qué | Cómo se entra | Desde dónde | Usuario | Contraseña |
|---|---|---|---|---|
| Wi-Fi de la Clínica | `SaludMovil-Clinica` | Cualquier equipo del personal | - | Hoja privada |
| Wi-Fi de la Comunidad | `SaludMovil-Comunidad` | Cualquier celular | - | Sin contraseña, con portal |
| kit01 | `ssh kitsalud@10.20.10.1` o `ssh kitsalud@100.90.225.113` por NetBird | IP de administración o NetBird | `kitsalud`, también para `sudo` | Hoja privada |
| clinica01 y comunidad01 | `ssh -J kitsalud@10.20.10.1 kitsalud@10.20.20.11` (`.12` para comunidad01) | Solo saltando por kit01 | `kitsalud` | Hoja privada |
| sw01 | `ssh -J kitsalud@10.20.10.1 admin@10.20.10.2` | IP de administración o NetBird | `admin` | Hoja privada |
| ap01 | `http://10.20.10.3` | IP de administración | `admin` | Hoja privada |
| Historia clínica (DHIS2), personal | `https://pacientes.salud.movil` | Red Interna | `ana.rojas`, `carlos.perez` | Hoja privada |
| Historia clínica (DHIS2), administradora | `https://pacientes.salud.movil` | Red Interna | `laura.gomez` | Hoja privada |
| Historia clínica (DHIS2), administrador | `https://pacientes.salud.movil` | Red Interna | `admin` | Hoja privada |
| Consulta de prerregistros | `https://consultas.salud.movil` | Red Interna | `ana.rojas`, `carlos.perez` (dominio) | Hoja privada |
| Archivos compartidos | `\\archivos.salud.movil\archivos` o `smb://archivos.salud.movil/archivos` | Red Interna | `SALUD\ana.rojas` (dominio) | Hoja privada |
| Monitoreo (Grafana) | `https://monitoreo.salud.movil` | IP de administración o NetBird | `laura.gomez` (dominio) | Hoja privada |
| Monitoreo, cuenta local | `https://monitoreo.salud.movil` | IP de administración o NetBird | `admin` | Hoja privada |
| Videos (Jellyfin), comunidad | `http://videos.salud.movil` | Interna o Comunidad | Se toca `comunidad` e **Iniciar sesión** | Sin contraseña |
| Videos, administración | `http://videos.salud.movil` | Solo red Interna. Se escribe el usuario a mano | `admin` | Hoja privada |
| Administrador del dominio | `sudo samba-tool` en clinica01 | clinica01 | `Administrator` | Hoja privada |
| Vault de Ansible | `~/.config/kitsalud/vault-pass` | Máquina de control | - | Hoja privada |
| Clave de las copias (restic) | `/etc/kitsalud/backup/restic.clave` | kit01 | - | Hoja privada |

La biblioteca (`http://biblioteca.salud.movil`), el formulario (`https://registro.salud.movil`), el portal (`http://portal.salud.movil`) y la raíz de certificados (`http://ca.salud.movil`) no piden cuenta.

Una cuenta del dominio se bloquea 15 minutos después de 5 intentos fallidos. Si pasa, `sudo samba-tool user unlock <usuario>` en clinica01 la libera.

## 4. Preparación

### Antes de salir, con Internet

En las tres laptops se clona `docs`, que trae los scripts de las pruebas.

```bash
git clone https://github.com/kitsalud-movil-plats1/docs.git
cd docs/pruebas
```

En Ubuntu y Fedora hacen falta `dig` y `smbclient`.

```bash
sudo apt-get install -y dnsutils smbclient          # Ubuntu
sudo dnf install -y bind-utils samba-client         # Fedora
```

La laptop Fedora necesita además el espacio de trabajo con todos los repositorios, Ansible y los archivos `vault-pass` y `ssh-pass` en `~/.config/kitsalud/`.

### En el laboratorio

1. Conectar kit01, sw01, ap01 y el disco USB, y encender en ese orden.
2. En las laptops, comentar los nombres del kit en `/etc/hosts`, porque si no apuntan a otro lado y nada abre.

   ```bash
   sudo sed -i '/salud\.movil/s/^/#/' /etc/hosts        # Linux
   sudo sed -i '' '/salud\.movil/s/^/#/' /etc/hosts     # Mac
   ```

3. Conectar la laptop Fedora por cable a `ether4` y ponerle la IP de administración. Reemplazar `<interfaz>` por el nombre del puerto de red (`ip -br link`).

   ```bash
   sudo nmcli con add type ethernet ifname <interfaz> con-name kit ipv4.method manual \
     ipv4.addresses 10.20.10.10/24 ipv4.gateway 10.20.10.1 ipv4.dns 10.20.20.10
   sudo nmcli con up kit
   ssh kitsalud@10.20.10.1 hostname                    # kit01
   ```

4. Conectar la Ubuntu y la Mac a su Wi-Fi. El Android se queda sin conectar.
5. Instalar la raíz del kit en los equipos que abran páginas HTTPS, con los pasos de `http://ca.salud.movil`. Si no se instala, el navegador muestra una advertencia que se acepta una vez.
6. Abrir `https://monitoreo.salud.movil` en la Fedora con `laura.gomez` y dejar a la vista el panel **Estado del kit**.
7. Revisar que todo está arriba. Desde `docs/pruebas` en la Fedora.

   ```bash
   ./scripts/P12-reinicio.sh estado
   ```

   Todas las líneas salen en `[ OK ]` y **Problemas ahora** está en 0.

## 5. Prueba por prueba

Todos los scripts se ejecutan desde `docs/pruebas`. Cada línea sale como `[ OK ]` o `[FALLA]` y el resultado queda guardado en `salidas/`. Si una prueba falla en vivo y no se resuelve en un par de minutos, se muestra su evidencia en `evidencias/evidencias.pdf` y se sigue con la siguiente.

### Comunidad

#### P5 Portal cautivo

| | |
|---|---|
| **Equipo** | iPhone y Mac |
| **Hacer** | Conectar el iPhone a `SaludMovil-Comunidad`. Se abre solo el portal. Leer las condiciones y tocar **Acepto y quiero entrar**. En la Mac, `./scripts/P05-portal.sh --aceptar` |
| **Debe verse** | El menú con biblioteca, videos y prerregistro. El script termina con `0 con falla` |
| **Explicar** | Sin aceptar, el firewall lleva todo el HTTP al portal y rechaza el HTTPS. Al aceptar, un servicio toma la MAC del cliente y la agrega por 8 horas a un set de nftables, que vale igual para IPv4 e IPv6 |

#### P1 Cliente comunitario

| | |
|---|---|
| **Equipo** | Mac |
| **Hacer** | `./scripts/P01-cliente.sh`. En el iPhone, mostrar los datos de la red en Ajustes, Wi-Fi |
| **Debe verse** | IPv4 `10.20.40.x`, IPv6 `fd5a:fc7e:d716:40:...`, gateway y DNS `10.20.20.10`, con `0 con falla` |
| **Explicar** | IPv4 llega por Kea. IPv6 llega por SLAAC con el anuncio de radvd, y el DNS por DHCPv6 sin estado |

#### P4 Acceso público local

| | |
|---|---|
| **Equipo** | iPhone y Mac |
| **Hacer** | En el iPhone, abrir un artículo de la biblioteca, reproducir un video como `comunidad` y llenar un prerregistro con datos ficticios. **Anotar el código.** En la Mac, `./scripts/P04-acceso-local.sh` |
| **Debe verse** | El contenido carga, el formulario entrega un código de cuatro letras y el script termina en `0 con falla` |
| **Explicar** | El formulario vive en comunidad01, pero guarda en la base de clinica01 con un usuario que solo puede insertar. comunidad01 nunca conserva datos de pacientes |

#### P3 Aislamiento

| | |
|---|---|
| **Equipo** | Mac y Fedora |
| **Hacer** | En la Mac, `./scripts/P03-aislamiento.sh <IP del iPhone>`. En la Fedora, `ssh kitsalud@10.20.10.1 'grep fw-drop /var/log/kitsalud/kit01/firewall.log \| tail -5'` |
| **Debe verse** | Todo bloqueado, con `0 con falla`, y cada intento en el log con la etiqueta `fw-drop F-20` |
| **Explicar** | La política es denegar y registrar. Desde la Comunidad no se llega a la Interna, a clinica01 ni a la gestión de kit01, y el AP aísla a los clientes entre sí |

#### P10 Firewall IPv6

| | |
|---|---|
| **Equipo** | Mac. Si no recibe IPv6, en la Fedora `./scripts/en-prueba01.sh P05-portal.sh --aceptar` y `./scripts/en-prueba01.sh P10-firewall-ipv6.sh` |
| **Hacer** | `./scripts/P10-firewall-ipv6.sh` |
| **Debe verse** | Por IPv6, la biblioteca responde y DHIS2 queda bloqueado, con `0 con falla` |
| **Explicar** | Los dos destinos están en la misma red, así que se ve que la regla es por equipo y por puerto. Es la misma política de IPv4, en la misma tabla |

### Clínica

#### P2 DNS

| | |
|---|---|
| **Equipo** | Ubuntu |
| **Hacer** | `./scripts/P02-dns.sh`. Abrir `http://biblioteca.salud.movil` en el navegador |
| **Debe verse** | Registros A y AAAA, ping y HTTP por nombre en las dos familias, con `0 con falla` |
| **Explicar** | BIND9 es autoritativo para `salud.movil` y delega `ad.salud.movil` a Samba. Nadie necesita recordar una IP |

#### P6 Aplicación clínica

| | |
|---|---|
| **Equipo** | Ubuntu |
| **Hacer** | Abrir `https://pacientes.salud.movil` y entrar con `ana.rojas`. En **Capture**, elegir la unidad del kit y el programa Atención primaria, registrar un paciente ficticio y guardar una consulta. Salir y entrar con `carlos.perez` para buscarlo por su documento. Después, en `https://consultas.salud.movil` con `ana.rojas`, buscar el código de P4 y marcarlo como atendido |
| **Debe verse** | El paciente aparece para el otro usuario, y el prerregistro hecho desde el celular está en la consulta |
| **Explicar** | DHIS2 usa cuentas propias, así sigue funcionando aunque el dominio falle. La consulta entra con el dominio por LDAPS, y solo el grupo `clinicos` puede ver prerregistros |

#### P7 Identidad

| | |
|---|---|
| **Equipo** | Windows o Ubuntu, y Fedora |
| **Hacer** | Abrir `\\archivos.salud.movil\archivos` con `SALUD\ana.rojas` y crear un archivo. Intentar con `SALUD\laura.gomez`. En la Fedora, entrar a Grafana con `laura.gomez` y luego intentar con `ana.rojas` |
| **Debe verse** | `ana.rojas` entra al recurso y `laura.gomez` no. En Grafana es al revés |
| **Explicar** | Un solo directorio y permisos por grupo. El recurso exige SMB3 con cifrado. Grafana usa LDAPS y conserva una cuenta local por si el dominio no responde |

#### P8 Tiempo

| | |
|---|---|
| **Equipo** | Fedora |
| **Hacer** | `./scripts/P08-tiempo.sh --estacion` |
| **Debe verse** | clinica01 y comunidad01 toman la hora de kit01, con `0 con falla` |
| **Explicar** | Chrony sirve la hora a todo el kit y sigue haciéndolo sin Internet. Kerberos y los logs dependen de que todos tengan la misma hora |

### Resiliencia

#### P11 Restauración

| | |
|---|---|
| **Equipo** | Fedora, con el disco USB conectado a kit01 |
| **Hacer** | `./scripts/P11-restauracion.sh` y confirmar con `s` |
| **Debe verse** | Se borran un archivo y una tabla, vuelven iguales desde restic, con `0 con falla` en poco más de un minuto |
| **Explicar** | kit01 extrae las copias de las VMs, que no tienen la clave del repositorio. El disco solo se monta durante la copia y el repositorio está cifrado |

#### P13 Diagnóstico

| | |
|---|---|
| **Equipo** | Fedora, con **Estado del kit** a la vista |
| **Hacer** | `./scripts/P13-diagnostico.sh dns` y confirmar con `s` |
| **Debe verse** | El DNS se pone en rojo en Grafana en menos de un minuto, el script muestra la alerta, la causa y el log, restaura y todo vuelve a verde |
| **Explicar** | Cómo se localiza una falla, con el panel primero, `systemctl` después y al final los logs centrales. Explicar el impacto para quien usa el kit |

#### P12 Reinicio

| | |
|---|---|
| **Equipo** | Fedora |
| **Hacer** | `./scripts/P12-reinicio.sh vms` |
| **Debe verse** | Las dos VMs se reinician y todo vuelve a verde en unos 45 s, sin tocar nada |
| **Explicar** | systemd, el arranque automático de libvirt y la política de reinicio de los contenedores. El orden entre aplicaciones lo resuelven sus reintentos |

#### P9 Pérdida de Internet

| | |
|---|---|
| **Equipo** | Todos |
| **Hacer** | Desconectar el cable de `enp170s0`, el que va a la red del laboratorio. **No el que va a sw01.** Esperar 1 minuto. En la Mac y en la Ubuntu, `./scripts/P09-sin-internet.sh`. En la Fedora, `ssh kitsalud@10.20.10.1 cat /run/kit-internet/modo`. Conectar el Android a `SaludMovil-Comunidad`. Al terminar, conectar el cable y esperar 2 minutos |
| **Debe verse** | `0 con falla` en los dos scripts, modo `sin`, y el Android abre el portal solo. Al volver el cable, modo `con` |
| **Explicar** | Todo lo esencial es local. Sin Internet, el DNS le responde a la Comunidad cualquier nombre externo con la dirección del portal, y por eso el celular lo detecta. NetBird es lo único que se cae |

## 6. Reinicio completo de kit01

Se hace en la prueba previa y no en la sustentación. Es el primer arranque real de kit01 con toda la configuración, y activa el kernel nuevo. Tener a mano un monitor y un teclado.

```bash
./scripts/P12-reinicio.sh reiniciar                  # en la Fedora, por NetBird
```

Tarda unos 3 minutos. El script revisa antes, reinicia, mide el tiempo y revisa después. Todo debe terminar en `[ OK ]`, con las dos VMs encendidas solas.

Si kit01 no vuelve, se conectan el monitor y el teclado y se revisa en este orden.

| Revisar | Comando | Qué buscar |
|---|---|---|
| Interfaces | `ip -br addr` | `enp170s0`, `lan0.10`, `br-srv` y `br-com` con sus direcciones |
| Firewall | `sudo nft list tables` | `inet filtro`, `ip nat_kit` y `bridge filtro_vms` |
| Servicios | `systemctl --failed` | Ninguno fallido |
| VMs | `sudo virsh list --all` | Las dos en `running` |
| Volumen | `findmnt /var/lib/libvirt/images` | Montado. Si no, `sudo mount /var/lib/libvirt/images` y encender las VMs |

## 7. Si algo falla en vivo

| Qué pasa | Qué hacer |
|---|---|
| Un script de `prueba01` o de Ansible no conecta | Revisar `netbird status` en la Fedora. Si NetBird no vuelve, usar `ssh kitsalud@10.20.10.1` por cable |
| Un celular no abre el portal solo | Abrir `http://portal.salud.movil` a mano |
| El navegador advierte sobre el certificado | Aceptar la advertencia o instalar la raíz de `http://ca.salud.movil` |
| Un servicio no responde | Mirar **Estado del kit**, que dice cuál, y seguir el diagnóstico de P13 |
| Una VM no responde | `sudo virsh start <vm>` en kit01 |
| Una cuenta del dominio quedó bloqueada | `sudo samba-tool user unlock <usuario>` en clinica01 |
| No hay forma de mostrar una prueba | Abrir `evidencias/evidencias.pdf` en esa prueba, explicar el resultado y seguir |

## 8. Al terminar

1. Conectar el cable de la WAN si sigue suelto y comprobar `cat /run/kit-internet/modo`.
2. En la Fedora, `./scripts/en-prueba01.sh --apagar` por si `prueba01` quedó encendida.
3. Sacar una copia manual si se quiere conservar lo registrado, con `sudo systemctl start backup.service` en kit01.
4. Apagar con `sudo kit-apagado` en kit01. Cuando se apague su indicador, desconectar el switch y el AP.

## 9. Lista de la prueba previa

| Prueba | Equipo | ¿Funcionó? | Tiempo | Notas |
|---|---|---|---|---|
| Reinicio de kit01 | Fedora | | | |
| Wi-Fi Clínica y Comunidad | Ubuntu, Mac y celulares | | | |
| P5 Portal cautivo | iPhone y Mac | | | |
| P1 Cliente comunitario | Mac | | | |
| P4 Acceso público local | iPhone y Mac | | | |
| P3 Aislamiento | Mac y Fedora | | | |
| P10 Firewall IPv6 | Mac | | | |
| P2 DNS | Ubuntu | | | |
| P6 Aplicación clínica | Ubuntu | | | |
| P7 Identidad | Windows o Ubuntu, y Fedora | | | |
| P8 Tiempo | Fedora | | | |
| P11 Restauración | Fedora | | | |
| P13 Diagnóstico | Fedora | | | |
| P12 Reinicio de las VMs | Fedora | | | |
| P9 Pérdida de Internet | Todos | | | |
