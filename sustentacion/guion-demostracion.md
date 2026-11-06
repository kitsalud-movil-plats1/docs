<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Guion de sustentación y demostración

**Proyecto final - Plataformas I - 2026-2** · Organización `kitsalud-movil-plats1`

Este guion lleva la demostración de las trece pruebas de aceptación de principio a fin, en vivo y con el kit real. Dice qué equipo usar, cómo entrar a cada servicio, qué comando ejecutar, qué debe verse, qué explicar y qué hacer si algo falla. Sirve igual para la prueba completa previa y para la sustentación. Las contraseñas no están aquí, porque los repositorios no guardan secretos. Están en la hoja privada del grupo.

## 1. Orden y tiempos

| Bloque | Contenido | Tiempo |
|---|---|---|
| Presentación | Problema, solución, decisiones, seguridad, continuidad y qué cambiaría con más usuarios | 35 min |
| Comunidad | P5, P1, P4, P3 y P10 | 15 min |
| Clínica | P2, P6, P7 y P8 | 15 min |
| Resiliencia | P11, P13, P12 y P9 | 20 min |
| Preguntas | | 10 min |
| **Total** | | **1 h 35 min** |

P9 va de última a propósito. Al quitar el cable de la WAN se cae NetBird, y los scripts que usan Ansible dejan de funcionar hasta que vuelve. El PC de administración sigue funcionando, porque llega a kit01 por el cable del switch.

## 2. Equipos y su papel

| Equipo | Papel | Conexión |
|---|---|---|
| Laptop Fedora | PC de administración. Abre Grafana, entra a kit01 y ejecuta los scripts del kit | Cable a `ether4` de sw01, con IP fija `10.20.10.10` |
| Laptop Ubuntu | Estación de la Clínica | Wi-Fi `SaludMovil-Clinica` |
| Laptop Mac | Cliente de la Comunidad | Wi-Fi `SaludMovil-Comunidad` |
| iPhone | Celular de la Comunidad para P5 y P4 | Wi-Fi `SaludMovil-Comunidad` |
| Android | Celular nuevo para ver el portal sin Internet en P9. **No se conecta antes de P9** | Wi-Fi `SaludMovil-Comunidad` |
| Windows, si hay | Abre el recurso `archivos` en P7 | Wi-Fi `SaludMovil-Clinica` |

La laptop Fedora no recibe IPv6 por Wi-Fi, y P10 se hace en la Mac. Va por cable porque Grafana y la gestión de los equipos solo responden a las direcciones de administración (sección 4).

## 3. Accesos y cuentas

| Qué | Cómo se entra | Desde dónde | Usuario | Contraseña |
|---|---|---|---|---|
| Wi-Fi de la Clínica | `SaludMovil-Clinica` | Cualquier equipo del personal | - | Hoja privada |
| Wi-Fi de la Comunidad | `SaludMovil-Comunidad` | Cualquier celular | - | Sin contraseña, con portal |
| kit01 | `ssh kitsalud@10.20.10.1` o `ssh kitsalud@100.90.225.113` por NetBird | IP de administración o NetBird | `kitsalud`, también para `sudo` | Hoja privada |
| clinica01 y comunidad01 | `ssh -J kitsalud@10.20.10.1 kitsalud@10.20.20.11` (`.12` para comunidad01) | Solo saltando por kit01 | `kitsalud` | Hoja privada |
| sw01 | `ssh admin@10.20.10.2` por cable, o `ssh -J kitsalud@100.90.225.113 admin@10.20.10.2` por NetBird | IP de administración o NetBird | `admin` | Hoja privada |
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

### PC de administración por cable al switch

Grafana, el SSH de kit01 y la gestión de sw01 y ap01 solo responden a las direcciones `10.20.10.10` a `10.20.10.29` y a NetBird. Un equipo en el Wi-Fi de la Clínica recibe una dirección `.100` o superior y queda bloqueado, aunque esté en la red Interna. Por eso el PC de administración va por cable y con dirección fija.

1. Conectar un cable de red del PC a `ether4` de sw01. Sirve cualquier puerto del 4 al 8. No usar `ether1` (kit01), `ether2` (AP), `ether3` (apagado) ni del 9 en adelante (apagados y fuera del bridge).
2. Apagar el Wi-Fi del PC. Si queda encendido puede competir con el cable por la ruta y por el DNS.
3. Ponerle la dirección fija. El primer PC usa `.10`, y si hay más, `.11`, `.12` y así hasta `.29`, sin repetir. La máscara es `255.255.255.0`, la puerta de enlace `10.20.10.1` y el DNS `10.20.20.10`.

   **Linux.** Reemplazar `<interfaz>` por el nombre del puerto de red (`ip -br link`).

   ```bash
   sudo nmcli con add type ethernet ifname <interfaz> con-name kit ipv4.method manual \
     ipv4.addresses 10.20.10.10/24 ipv4.gateway 10.20.10.1 ipv4.dns 10.20.20.10
   sudo nmcli con up kit
   ```

   **Mac.** `networksetup -listallnetworkservices` muestra el nombre del puerto de red.

   ```bash
   sudo networksetup -setmanual "<puerto>" 10.20.10.11 255.255.255.0 10.20.10.1
   sudo networksetup -setdnsservers "<puerto>" 10.20.20.10
   ```

   **Windows.** En PowerShell como administrador, con el nombre que muestra `Get-NetAdapter`.

   ```powershell
   netsh interface ipv4 set address name="Ethernet" static 10.20.10.12 255.255.255.0 10.20.10.1
   netsh interface ipv4 set dns name="Ethernet" static 10.20.20.10
   ```

4. Comprobar la conexión.

   ```bash
   ping -c 2 10.20.10.1                 # responde kit01
   ssh kitsalud@10.20.10.1 hostname     # kit01
   ```

5. Comentar los nombres del kit en `/etc/hosts` e instalar la raíz, con los pasos 2 y 5 de la lista que sigue.
6. Abrir `https://monitoreo.salud.movil` y entrar con `laura.gomez`.

Desde este PC se llega a lo siguiente.

| Qué | Cómo |
|---|---|
| Grafana | `https://monitoreo.salud.movil`, tablero **Estado del kit** |
| kit01 | `ssh kitsalud@10.20.10.1` |
| clinica01 y comunidad01 | `ssh -J kitsalud@10.20.10.1 kitsalud@10.20.20.11` (`.12` para comunidad01) |
| sw01 | `ssh admin@10.20.10.2` |
| ap01 | `http://10.20.10.3` |
| Servicios clínicos | `https://pacientes.salud.movil`, `https://consultas.salud.movil` y `\\archivos.salud.movil\archivos` |

Hay que tener en cuenta lo siguiente.

- La administración es solo por IPv4. El SSH por IPv6 está bloqueado a propósito.
- NetBird solo hace falta para los scripts que usan Ansible, que son P11 y `P12-reinicio.sh estado`. El resto funciona por el cable.
- Sin NetBird también se trabaja. Si hay que confirmar el estado del kit, en kit01 se usa `systemctl --failed` y el tablero de Grafana.
- Al terminar se quita la dirección fija. En Linux, `sudo nmcli con delete kit`. En Mac, `sudo networksetup -setdhcp "<puerto>"` y `sudo networksetup -setdnsservers "<puerto>" empty`. En Windows, `netsh interface ipv4 set address name="Ethernet" source=dhcp` y `netsh interface ipv4 set dns name="Ethernet" source=dhcp`.

### En el laboratorio

1. Conectar kit01, sw01, ap01 y el disco USB, y encender en ese orden.
2. En las laptops, comentar los nombres del kit en `/etc/hosts`, porque si no apuntan a otro lado y nada abre.

   ```bash
   sudo sed -i '/salud\.movil/s/^/#/' /etc/hosts        # Linux
   sudo sed -i '' '/salud\.movil/s/^/#/' /etc/hosts     # Mac
   ```

3. Conectar el PC de administración por cable, como dice la sección anterior.
4. Conectar la Ubuntu y la Mac a su Wi-Fi. El Android se queda sin conectar.
5. Instalar la raíz del kit en los equipos que abran páginas HTTPS, con los pasos de `http://ca.salud.movil`. Si no se instala, el navegador muestra una advertencia que se acepta una vez.
6. Abrir `https://monitoreo.salud.movil` en la Fedora con `laura.gomez` y dejar a la vista el panel **Estado del kit**. Dejar también una terminal con `ssh kitsalud@10.20.10.1`, que es la **sesión de kit01** de las pruebas, y otra en `docs/pruebas`.
7. Revisar que todo está arriba. Desde `docs/pruebas` en la Fedora.

   ```bash
   ./scripts/P12-reinicio.sh estado
   ```

   Todas las líneas salen en `[ OK ]`, con 23 bien, y **Problemas ahora** está en 0.

## 5. Prueba por prueba

Todos los scripts se ejecutan desde `docs/pruebas`. Cada línea sale como `[ OK ]` o `[FALLA]` y el resultado queda guardado en `salidas/`. Si una prueba falla en vivo y no se resuelve en un par de minutos, se muestra su evidencia en `evidencias/evidencias.pdf` y se sigue con la siguiente.

La mayoría de las pruebas se hace a mano, porque así se ve lo que pasa y se explica mejor. Un comando se ejecuta en la **sesión de kit01** cuando el paso lo dice.

| Prueba | Cómo se hace | Qué necesita |
|---|---|---|
| P5, P1, P4 y P10 | Celular y script en la Mac | Portal aceptado |
| P2 | Script en la Ubuntu | Wi-Fi de la Clínica |
| P3 | Navegador y `curl` en la Mac, log en vivo en kit01 | Portal aceptado y sesión de kit01 |
| P6 y P7 | Navegador y explorador de archivos | Red Interna y usuarios del dominio |
| P8 | Comandos en kit01 | Sesión de kit01 |
| P11 | Script en la Fedora | NetBird, vault, disco USB y el explorador abierto en `archivos` |
| P13 y P12 | Comandos en kit01 con Grafana a la vista | Sesión de kit01 y Grafana abierto |
| P9 | Cable y clientes reales | Android sin conectar antes |

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
| **Equipo** | Mac con el portal aceptado, y sesión de kit01 en la Fedora |
| **Tener en cuenta** | Lo bloqueado no responde, así que `curl` espera 5 s y termina sin conexión. Ese es el resultado correcto. El log del firewall también trae ruido de la red del laboratorio, por eso se filtra por `fw-drop F-20` |

1. En la sesión de kit01, dejar el log a la vista.

   ```bash
   tail -f /var/log/kitsalud/kit01/firewall.log | grep --line-buffered 'fw-drop F-20'
   ```

2. En la Mac, abrir `https://pacientes.salud.movil` en el navegador. La página no carga.
3. En la terminal de la Mac, intentar por las dos familias.

   ```bash
   curl -4 -m 5 https://pacientes.salud.movil
   curl -6 -m 5 https://pacientes.salud.movil
   ```

4. Ver la IP del iPhone en Ajustes, Wi-Fi, y en la Mac ejecutar `ping -c 3 <IP del iPhone>`. No hay respuesta. Un iPhone puede no responder ping por sí mismo, así que es más claro con dos laptops en la Comunidad.
5. Detener el log con Ctrl+C.

| | |
|---|---|
| **Debe verse** | Cada intento aparece en kit01 con `fw-drop F-20`, `IN=br-com` y la dirección de la Mac, con destino `10.20.20.11` y su pareja en IPv6 |
| **Explicar** | La política es denegar y registrar. Desde la Comunidad no se llega a la Interna, a clinica01 ni a la gestión de kit01, y el AP aísla a los clientes entre sí |
| **Si falla** | En la Mac, `./scripts/P03-aislamiento.sh <IP del iPhone>` revisa todos los destinos de una vez |

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
| **Equipo** | Ubuntu en `SaludMovil-Clinica` |
| **Tener en cuenta** | La interfaz de DHIS2 está en inglés. Solo datos ficticios. Tener a mano el código de P4. Una cuenta del dominio se bloquea con 5 intentos fallidos |

1. Abrir `https://pacientes.salud.movil` y entrar con `ana.rojas`.
2. Abrir **Capture**, elegir la unidad del kit y el programa Atención primaria.
3. Registrar un paciente ficticio y guardar una consulta.
4. Salir y entrar con `carlos.perez`.
5. Buscar el paciente por su documento.
6. Abrir `https://consultas.salud.movil` y entrar con `ana.rojas`.
7. Buscar el código de P4 y marcarlo como atendido.

| | |
|---|---|
| **Debe verse** | El paciente aparece para el otro usuario, y el prerregistro hecho desde el celular está en la consulta |
| **Explicar** | DHIS2 usa cuentas propias, así sigue funcionando aunque el dominio falle. La consulta entra con el dominio por LDAPS, y solo el grupo `clinicos` puede ver prerregistros |

#### P7 Identidad

| | |
|---|---|
| **Equipo** | Windows, Ubuntu o Mac en `SaludMovil-Clinica`, y el PC de administración |
| **Tener en cuenta** | El sistema recuerda la sesión del recurso, así que hay que cerrarla antes de probar con otro usuario. En Grafana hay que usar el PC de administración |

1. Abrir el recurso con `SALUD\ana.rojas`. En Windows, `\\archivos.salud.movil\archivos`. En Ubuntu y Mac, `smb://archivos.salud.movil/archivos` desde el explorador.
2. Crear un archivo.
3. Cerrar la sesión del recurso.

   ```bash
   gio mount -u smb://archivos.salud.movil/archivos       # Ubuntu
   ```

   En Windows, `net use \\archivos.salud.movil\archivos /delete`. En Mac, expulsar el recurso en Finder.
4. Abrir otra vez el recurso con `SALUD\laura.gomez`. Queda rechazada.
5. En el PC de administración, entrar a `https://monitoreo.salud.movil` con `laura.gomez`. Entra.
6. Cerrar la sesión de Grafana e intentar con `ana.rojas`. Queda rechazada.
7. Entrar otra vez con `laura.gomez` y dejar **Estado del kit** a la vista.

| | |
|---|---|
| **Debe verse** | `ana.rojas` entra al recurso y `laura.gomez` no. En Grafana es al revés |
| **Explicar** | Un solo directorio y permisos por grupo. El recurso exige SMB3 con cifrado. Grafana usa LDAPS y conserva una cuenta local por si el dominio no responde |

#### P8 Tiempo

| | |
|---|---|
| **Equipo** | Sesión de kit01 en la Fedora |
| **Tener en cuenta** | `chronyc clients` necesita `sudo`, y sin él responde `501 Not authorised`. La lista también trae clientes antiguos, y se miran los de las VMs y sw01. El SSH a las VMs pide la contraseña de `kitsalud` |

1. Ver quién le pide la hora a kit01.

   ```bash
   sudo chronyc -n clients
   ```

2. Comprobar que las dos VMs la toman de kit01.

   ```bash
   ssh kitsalud@10.20.20.11 chronyc -n sources
   ssh kitsalud@10.20.20.12 chronyc -n sources
   ```

| | |
|---|---|
| **Debe verse** | En `clients`, las direcciones de las VMs y `10.20.10.2` (sw01). En `sources`, una línea `^* 10.20.20.10` en cada VM, y `^*` indica la fuente en uso |
| **Explicar** | Chrony sirve la hora a todo el kit y sigue haciéndolo sin Internet. Kerberos y los logs dependen de que todos tengan la misma hora |

### Resiliencia

#### P11 Restauración

| | |
|---|---|
| **Equipo** | Fedora, y Ubuntu con el explorador abierto en `archivos` como `SALUD\ana.rojas` |
| **Tener en cuenta** | Es la única prueba que necesita un script, porque restaurar toca tres equipos y es fácil equivocarse a mano. Necesita NetBird, el vault y el disco USB conectado a kit01, y por eso va antes de P9. Usa el archivo `prueba-p11.txt` y una tabla de prueba, sin tocar datos reales |

1. En la Ubuntu, mostrar `prueba-p11.txt` en el explorador.
2. En la Fedora, iniciar la prueba.

   ```bash
   ./scripts/P11-restauracion.sh
   ```

3. El script hace una copia y pregunta si sigue. Responder `s`, y borra el archivo.
4. Cuando el script se detenga, actualizar el explorador en la Ubuntu. El archivo ya no está.
5. Presionar Enter en la Fedora. El script restaura desde el disco.
6. Actualizar el explorador en la Ubuntu. El archivo volvió.

| | |
|---|---|
| **Debe verse** | El archivo desaparece y vuelve igual, con 16 bien y `0 con falla` en poco más de un minuto, sin contar la pausa |
| **Explicar** | kit01 extrae las copias de las VMs, que no tienen la clave del repositorio. El disco solo se monta durante la copia y el repositorio está cifrado |
| **Si falla** | El script deja una copia en `/root/p11` de clinica01, y con `sudo cp -a /root/p11/prueba-p11.txt /srv/samba/archivos/` vuelve el archivo |

#### P13 Diagnóstico

| | |
|---|---|
| **Equipo** | Sesión de kit01 en la Fedora con **Estado del kit** a la vista, y un cliente para ver el síntoma |
| **Tener en cuenta** | Se hace a mano porque la prueba evalúa que el grupo localice la falla. Detener el DNS deja a todos los clientes sin nombres nuevos, y un navegador puede seguir mostrando lo que ya tenía en caché. Por eso el síntoma se ve con `dig`. No recargar Grafana mientras el DNS está detenido. El SSH sigue funcionando, porque usa la dirección IP |

1. En la sesión de kit01, provocar la falla.

   ```bash
   sudo systemctl stop named
   ```

2. En un cliente, mostrar el síntoma.

   ```bash
   dig @10.20.20.10 pacientes.salud.movil +time=2 +tries=1
   ```

3. Esperar el rojo en Grafana, cerca de 35 s.
4. Localizar la falla en kit01.

   ```bash
   systemctl status named --no-pager | head -5
   journalctl -u named -n 5 --no-pager
   ```

5. Explicar el impacto y arreglarla.

   ```bash
   sudo systemctl start named
   ```

6. Repetir el `dig` del paso 2 y esperar el verde en Grafana.

| | |
|---|---|
| **Debe verse** | `dig` sin respuesta, DNS en rojo en menos de un minuto, `inactive (dead)` en `systemctl`, y todo en verde al arrancarlo |
| **Explicar** | Cómo se localiza una falla, con el panel primero, `systemctl` después y al final los logs. El impacto es que nadie resuelve nombres, aunque DHIS2 y los demás servicios siguen arriba |
| **Si falla** | `./scripts/P13-diagnostico.sh dns` hace lo mismo y restaura solo |

#### P12 Reinicio

| | |
|---|---|
| **Equipo** | Sesión de kit01 en la Fedora con **Estado del kit** a la vista |
| **Tener en cuenta** | Durante unos 45 s no hay DHIS2, biblioteca, videos ni recurso `archivos`, así que nadie debe estar en medio de otra prueba. La red de kit01 sigue arriba. Grafana sigue abierto porque corre en kit01. Estos comandos no necesitan `sudo` |

1. En la sesión de kit01, reiniciar las dos VMs.

   ```bash
   virsh -c qemu:///system reboot clinica01
   virsh -c qemu:///system reboot comunidad01
   ```

2. Mirar Grafana sin tocar nada. Los servicios pasan a rojo y vuelven solos.
3. Cuando todo esté en verde, abrir `https://pacientes.salud.movil` en la Ubuntu.

| | |
|---|---|
| **Debe verse** | Las dos VMs se reinician y todo vuelve a verde en unos 45 s, sin intervención |
| **Explicar** | systemd, el arranque automático de libvirt y la política de reinicio de los contenedores. El orden entre aplicaciones lo resuelven sus reintentos |
| **Si falla** | `./scripts/P12-reinicio.sh estado` en la Fedora dice qué quedó abajo |

#### P9 Pérdida de Internet

| | |
|---|---|
| **Equipo** | Todos |
| **Tener en cuenta** | Va de última, porque sin WAN se cae NetBird y dejan de funcionar P11 y `P12-reinicio.sh estado`. El PC de administración sigue con SSH y Grafana por el cable. kit01 tarda cerca de 1 minuto en pasar a modo `sin`. El Android no se conecta antes de esta prueba |

1. Desconectar el cable de `enp170s0`, el que va a la red del laboratorio. **No el que va a sw01.**
2. Esperar 1 minuto y comprobar el modo en la sesión de kit01.

   ```bash
   cat /run/kit-internet/modo        # sin
   ```

3. En la Ubuntu, abrir `https://pacientes.salud.movil` y buscar un paciente.
4. En el iPhone, abrir la biblioteca y un video, y llenar un prerregistro.
5. Conectar el Android a `SaludMovil-Comunidad`. El portal se abre solo.
6. Para revisar todo por IPv4 e IPv6, ejecutar `./scripts/P09-sin-internet.sh` en la Mac y en la Ubuntu.
7. Conectar el cable y esperar 2 minutos.
8. Comprobar otra vez el modo, que vuelve a `con`.

| | |
|---|---|
| **Debe verse** | Los servicios del kit siguen funcionando, modo `sin`, `0 con falla` en los dos scripts, y el Android abre el portal solo |
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
| Grafana o el SSH no responden desde el PC | Revisar que tenga una dirección entre `10.20.10.10` y `.29` (`ip -br addr`), que el cable esté en un puerto del 4 al 8, que el Wi-Fi esté apagado y que los nombres del kit estén comentados en `/etc/hosts` |
| Un cliente Wi-Fi no recibe respuestas por IPv6 | En kit01, `systemctl is-active kit-vecinos` y `journalctl -u kit-vecinos -n 20 -o cat`, donde debe aparecer su dirección. Si está detenido, `sudo systemctl restart kit-vecinos` |
| El log de P3 no muestra nada | Revisar que la Mac esté en la Comunidad, con el portal aceptado, y que el `grep` incluya `F-20` |
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
| PC de administración por cable | Fedora | | | |
| Grafana, sw01 y ap01 desde el PC | Fedora | | | |
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
