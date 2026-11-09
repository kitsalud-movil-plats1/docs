<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Guion de sustentación y demostración

**Proyecto final - Plataformas I - 2026-2** · Organización `kitsalud-movil-plats1`

Las contraseñas no están aquí, porque los repositorios no guardan secretos. Están en la hoja privada del grupo.

Cada prueba dice en qué red conectarse, qué hacer, qué mostrar y qué explicar. Sirve cualquier equipo, y los comandos están para Linux, Mac y Windows. Solo P11 usa un script. Si una prueba falla y no se resuelve en un par de minutos, se abre esa prueba en `evidencias/evidencias.pdf` y se sigue.

## Accesos

| Qué | Cómo se entra | Desde dónde | Usuario | Contraseña |
|---|---|---|---|---|
| Wi-Fi de la Clínica | `SaludMovil-Clinica` | Cualquier equipo del personal | - | Hoja privada |
| Wi-Fi de la Comunidad | `SaludMovil-Comunidad` | Cualquier celular | - | Sin contraseña, con portal |
| kit01 | `ssh kitsalud@10.20.10.1` o `ssh kitsalud@100.90.225.113` por NetBird | IP de administración o NetBird | `kitsalud`, también para `sudo` | Hoja privada |
| clinica01 y comunidad01 | `ssh -J kitsalud@10.20.10.1 kitsalud@10.20.20.11` (`.12` para comunidad01) | Solo saltando por kit01 | `kitsalud` | Hoja privada |
| sw01 | `ssh admin@10.20.10.2` por cable, o `ssh -J kitsalud@100.90.225.113 admin@10.20.10.2` por NetBird | IP de administración o NetBird | `admin` | Hoja privada |
| ap01 | `http://10.20.10.3` | IP de administración | `admin` | Hoja privada |
| Historia clínica (DHIS2), personal | `https://pacientes.salud.movil` | Red Interna | `ana.rojas`, `carlos.perez` | Hoja privada |
| Consulta de prerregistros | `https://consultas.salud.movil` | Red Interna | `ana.rojas`, `carlos.perez` (dominio) | Hoja privada |
| Archivos compartidos | `\\archivos.salud.movil\archivos` o `smb://archivos.salud.movil/archivos` | Red Interna | `SALUD\ana.rojas` (dominio) | Hoja privada |
| Monitoreo (Grafana) | `https://monitoreo.salud.movil` | IP de administración o NetBird | `laura.gomez` (dominio) | Hoja privada |
| Monitoreo, cuenta local | `https://monitoreo.salud.movil` | IP de administración o NetBird | `admin` | Hoja privada |
| Videos (Jellyfin), comunidad | `http://videos.salud.movil` | Interna o Comunidad | Se toca `comunidad` e **Iniciar sesión** | Sin contraseña |

**Administración.** Grafana, el SSH y la gestión de los equipos solo responden en el puerto `ether4` de sw01. Se conecta un equipo por cable a ese puerto, con la red en automático y el Wi-Fi apagado, y recibe una dirección entre `10.20.10.10` y `10.20.10.28`. Si no la recibe, se le pone a mano la `10.20.10.29`, con máscara `255.255.255.0`, puerta de enlace `10.20.10.1` y DNS `10.20.20.10`.

Cuando un paso dice **en kit01**, es en una sesión abierta desde ese equipo con `ssh kitsalud@10.20.10.1`.

## P1 Cliente comunitario

**Red.** `SaludMovil-Comunidad`.

1. Conectar un equipo a `SaludMovil-Comunidad`. Cuando aparezca el portal, tocar **Acepto y quiero entrar**. Este equipo se usa hasta P4.
2. Ver su configuración.

| Sistema | Dirección y gateway | DNS |
|---|---|---|
| Linux | `ip a` y `ip r` | `resolvectl dns` |
| Mac | `networksetup -getinfo Wi-Fi` | `networksetup -getdnsservers Wi-Fi` |
| Windows | `ipconfig /all` | La misma salida |
| iPhone | Ajustes, Wi-Fi, tocar la **i** de la red | La misma pantalla |

**Mostrar.**

- IPv4 `10.20.40.x` con gateway `10.20.40.1`.
- IPv6 `fd5a:fc7e:d716:40:...` con gateway `fe80::1`.
- DNS `10.20.20.10`.

**Explicar.** IPv4 llega por DHCP con Kea. IPv6 se arma con el anuncio de radvd (SLAAC), y el DNS llega por DHCPv6 sin estado.

## P2 DNS

**Red.** `SaludMovil-Clinica`, en una laptop.

1. Conectar la laptop a `SaludMovil-Clinica`.
2. Preguntar la dirección IPv4 y la IPv6 de cada nombre, cambiando `<nombre>` por los de la lista.

| Sistema | IPv4 | IPv6 |
|---|---|---|
| Linux y Mac | `dig <nombre> A +short` | `dig <nombre> AAAA +short` |
| Windows | `nslookup -type=A <nombre>` | `nslookup -type=AAAA <nombre>` |

| Nombre | Servicio | IPv4 | IPv6 |
|---|---|---|---|
| `pacientes.salud.movil` | Historia clínica | `10.20.20.11` | `fd5a:fc7e:d716:20::11` |
| `archivos.salud.movil` | Recursos compartidos | `10.20.20.11` | `fd5a:fc7e:d716:20::11` |
| `biblioteca.salud.movil` | Biblioteca | `10.20.20.12` | `fd5a:fc7e:d716:20::12` |
| `registro.salud.movil` | Prerregistro | `10.20.20.12` | `fd5a:fc7e:d716:20::12` |
| `ntp.salud.movil` | Hora | `10.20.20.10` | `fd5a:fc7e:d716:20::10` |

3. Hacer ping por nombre a `biblioteca.salud.movil` y a `pacientes.salud.movil`.

| Sistema | IPv4 | IPv6 |
|---|---|---|
| Linux | `ping -4 -c 3 <nombre>` | `ping -6 -c 3 <nombre>` |
| Mac | `ping -c 3 <nombre>` | `ping6 -c 3 <nombre>` |
| Windows | `ping -4 <nombre>` | `ping -6 <nombre>` |

4. Abrir en el navegador `http://biblioteca.salud.movil` y `https://pacientes.salud.movil`, escribiendo solo el nombre.

**Mostrar.**

- Cada nombre responde con su dirección en IPv4 y en IPv6.
- El ping responde por las dos familias.
- Las páginas abren sin escribir una dirección IP.

**Explicar.** BIND9 en kit01 es la autoridad de `salud.movil`, y delega `ad.salud.movil` a Samba. Nadie tiene que recordar una dirección, y si un servicio cambia de equipo solo cambia su registro.

## P3 Aislamiento

**Red.** `SaludMovil-Comunidad`, con el equipo de P1. El log se mira en kit01.

1. En el navegador, intentar abrir estas tres direcciones. Ninguna carga.
   - `https://pacientes.salud.movil`
   - `https://monitoreo.salud.movil`
   - `http://10.20.10.3`
2. Repetir el primero por las dos familias.

| Sistema | IPv4 | IPv6 |
|---|---|---|
| Linux y Mac | `curl -4 -m 5 https://pacientes.salud.movil` | `curl -6 -m 5 https://pacientes.salud.movil` |
| Windows | `curl.exe -4 -m 5 https://pacientes.salud.movil` | `curl.exe -6 -m 5 https://pacientes.salud.movil` |

3. En kit01, ver los intentos en el log.

```bash
grep 'fw-drop F-20' /var/log/kitsalud/kit01/firewall.log | tail -5
```

**Mostrar.**

- `curl` espera 5 s y termina sin conexión. Ese es el resultado correcto.
- En el log, los intentos con la dirección del cliente como `SRC`, y `10.20.20.11` y su pareja en IPv6 como `DST`.

**Explicar.** La política es denegar y registrar. Desde la Comunidad no se llega a la red Interna, a clinica01 ni a la gestión. Entre dos invitados el AP no aísla, porque su firmware solo lo hace en el SSID de la Clínica, y queda como riesgo aceptado.

## P4 Acceso público local

**Red.** `SaludMovil-Comunidad`, con el equipo de P1.

1. Abrir `http://portal.salud.movil`. Aparece el menú con tres opciones, y debajo el estado de los servicios.
2. Entrar a **Biblioteca de salud**. Abrir Wikipedia médica y leer un artículo, por ejemplo sobre fiebre o vacunas. Volver y mostrar que también están Vikidia y las simulaciones de PhET.
3. Entrar a **Videos**. Tocar `comunidad` y después **Iniciar sesión**, sin contraseña. Reproducir unos segundos de un video de la biblioteca Salud, y mostrar que existe la biblioteca Comunidad.
4. Entrar a **Prerregistro para la consulta**. Llenar el formulario con datos ficticios, con número de documento, y tocar **Enviar prerregistro**.
5. **Anotar el código** que entrega. Se usa en P6.

**Mostrar.**

- El contenido carga desde el kit.
- El video se reproduce.
- El formulario entrega un código de cuatro letras.

**Explicar.** Los videos van a 480p para que muchos los vean a la vez. El formulario vive en comunidad01, pero guarda en la base de clinica01 con un usuario que solo puede insertar. comunidad01 nunca conserva datos de pacientes.

## P5 Portal cautivo

**Red.** `SaludMovil-Comunidad`, con un equipo que no se haya conectado hoy. Un equipo que ya aceptó no vuelve a ver el portal durante 8 horas.

1. Conectar el equipo nuevo a `SaludMovil-Comunidad`. El portal se abre solo. Si no se abre, abrir `http://portal.salud.movil`.
2. Mostrar las condiciones, que dicen que es una red local y que el acceso dura 8 horas.
3. Tocar **Acepto y quiero entrar**. Aparece el menú.
4. En kit01, ver los equipos aceptados.

```bash
sudo nft list set inet filtro portal_ok
```

**Mostrar.**

- El portal aparece sin escribir nada.
- Después de aceptar, la MAC del equipo está en la lista con su tiempo restante.

**Explicar.** Sin aceptar, el firewall lleva todo el HTTP al portal y rechaza el HTTPS. Al aceptar, un servicio agrega la MAC por 8 horas a un set de nftables, que vale igual para IPv4 e IPv6.

## P6 Aplicación clínica

**Red.** `SaludMovil-Clinica`, en una laptop. La interfaz de DHIS2 está en inglés, y todos los datos son ficticios.

1. Abrir `https://pacientes.salud.movil` y entrar con `ana.rojas`.
2. Abrir la app **Dashboard** y el tablero **Brigada de salud**. Mostrar **Atenciones por día** y **Motivos de consulta**. Un minuto es suficiente.
3. Abrir la app **Capture**, elegir la unidad del kit y el programa **Atención primaria**. Mostrar la lista de pacientes.
4. Registrar un paciente nuevo, con nombre, apellido, documento inventado, fecha de nacimiento y sexo.
5. Agregarle una **Consulta** con motivo principal, peso y temperatura, y guardar.
6. Salir y entrar con `carlos.perez`. En **Capture**, buscar el paciente por su documento y abrirlo.
7. Abrir `https://consultas.salud.movil` y entrar con `ana.rojas`.
8. Mostrar la lista **Por atender**, buscar el código de P4 y tocar **Marcar como atendido**. Pasa a **Atendidos hoy**.

Con eso basta. No hace falta entrar a otras apps ni a la configuración de DHIS2.

**Mostrar.**

- El paciente que registró una persona lo encuentra otra.
- El prerregistro hecho desde el celular llegó a la consulta.

**Explicar.** DHIS2 usa cuentas propias, así sigue funcionando aunque el dominio falle. La consulta entra con el dominio, y solo el grupo `clinicos` puede ver prerregistros. El tablero se actualiza cada 30 minutos, por eso el paciente nuevo no aparece ahí de inmediato.

## P7 Identidad

**Qué demuestra.** Un usuario se crea una sola vez en el dominio, y su grupo decide a qué entra. Se prueba con dos usuarios en dos servicios distintos.

| Usuario | Grupo | Recurso `archivos` | Grafana |
|---|---|---|---|
| `ana.rojas` | `clinicos` | Entra | No entra |
| `laura.gomez` | `admins` | No entra | Entra |

**Red.** `SaludMovil-Clinica` para el recurso, y el equipo de administración para Grafana.

1. Abrir el recurso con el usuario `SALUD\ana.rojas`.

| Sistema | Cómo |
|---|---|
| Linux | Archivos, Otras ubicaciones, `smb://archivos.salud.movil/archivos` |
| Mac | Finder, Ir, Conectarse al servidor, `smb://archivos.salud.movil/archivos` |
| Windows | Explorador, `\\archivos.salud.movil\archivos` |

2. Crear un archivo de texto.
3. Cerrar la sesión del recurso, porque el sistema la recuerda.

| Sistema | Cómo |
|---|---|
| Linux | `gio mount -u smb://archivos.salud.movil/archivos` |
| Mac | Expulsar el recurso en Finder |
| Windows | `net use \\archivos.salud.movil\archivos /delete` |

4. Abrir otra vez el recurso, ahora con `SALUD\laura.gomez`. Queda rechazada.
5. En el equipo de administración, abrir `https://monitoreo.salud.movil` y entrar con `laura.gomez`. Entra.
6. Salir de Grafana e intentar con `ana.rojas`. Queda rechazada.
7. Entrar otra vez con `laura.gomez` y dejar el tablero **Estado del kit** abierto. Se usa en P12 y P13.

**Mostrar.**

- `ana.rojas` entra al recurso y `laura.gomez` no.
- En Grafana es al revés.

**Explicar.** Un solo directorio y permisos por grupo. El recurso exige SMB3 con cifrado. Grafana conserva una cuenta local por si el dominio no responde. Una cuenta se bloquea 15 minutos después de 5 intentos fallidos.

## P8 Tiempo

**Red.** Equipo de administración. Todo se ejecuta en kit01.

1. Ver quién le pide la hora a kit01.

```bash
sudo chronyc -n clients
```

2. Comprobar que las dos VMs toman la hora de kit01.

```bash
ssh kitsalud@10.20.20.11 chronyc -n sources
ssh kitsalud@10.20.20.12 chronyc -n sources
```

3. Mostrar que los logs de distintos equipos se pueden comparar. La entrada del paso 2 se generó en clinica01 y quedó en kit01.

```bash
date
grep -h Accepted /var/log/kitsalud/clinica01/auth.log | tail -2
```

4. Mostrar que el dominio entrega un ticket con esa misma hora. Pide la contraseña de `ana.rojas`.

```bash
ssh kitsalud@10.20.20.11
kinit ana.rojas@AD.SALUD.MOVIL
klist
kdestroy
exit
```

**Mostrar.**

- En la primera lista, las VMs y `10.20.10.2`, que es sw01.
- En cada VM, una línea que empieza con `^*` y dice `10.20.20.10`. El `^*` indica la fuente en uso.
- La hora del log coincide con la de `date`, aunque el evento pasó en otro equipo.
- El ticket de `klist` empieza a la hora actual.

**Explicar.** Chrony sirve la hora a todo el kit y sigue haciéndolo sin Internet. Kerberos rechaza a un equipo con más de 5 minutos de diferencia con el dominio, y por eso sin hora común no hay inicio de sesión. Con una sola hora, los logs de todos los equipos se pueden ordenar para seguir una falla. No se desajusta la hora en vivo, porque dejaría sin dominio a quienes lo están usando.

## P9 Pérdida de Internet

**Red.** Un cliente en cada Wi-Fi y el equipo de administración, que sigue funcionando por el cable.

1. Desconectar el cable de `enp170s0`, el que va a la red del laboratorio. **No el que va a sw01.**
2. Esperar 1 minuto y comprobar en kit01 que el kit lo detectó. Debe decir `sin`.

```bash
cat /run/kit-internet/modo
```

3. Comprobar la hora en kit01. Sigue con `Leap status : Normal`.

```bash
chronyc tracking
```

4. En la Clínica, resolver un nombre como en P2, abrir `https://pacientes.salud.movil` y buscar un paciente, y abrir el recurso `archivos`.
5. En la Comunidad, abrir la biblioteca y llenar un prerregistro.
6. Si hay un equipo que no haya entrado hoy, conectarlo a la Comunidad. El portal se abre solo, aunque no haya Internet.
7. Conectar el cable y esperar 2 minutos. El modo vuelve a `con` y NetBird se recupera. P11 lo necesita.

**Mostrar.**

- Nombres, hora, DHIS2, prerregistro, biblioteca y archivos siguen funcionando.

**Explicar.** Todo lo esencial es local. Sin Internet, el DNS le responde a la Comunidad cualquier nombre externo con la dirección del portal, y por eso el celular lo detecta. NetBird es lo único que se cae, y el kit no lo necesita para atender.

## P10 Firewall IPv6

**Red.** `SaludMovil-Comunidad`, con un equipo con el portal aceptado.

1. Probar por IPv6 los destinos permitidos y los bloqueados, cambiando `<url>` por los de la lista.

| Sistema | Comando |
|---|---|
| Linux y Mac | `curl -6 -k -I -m 5 <url>` |
| Windows | `curl.exe -6 -k -I -m 5 <url>` |

| Destino | Puerto | Resultado |
|---|---|---|
| `http://biblioteca.salud.movil` | 80 | Permitido, responde `200` |
| `http://videos.salud.movil` | 80 | Permitido, responde `302` |
| `https://registro.salud.movil` | 443 | Permitido, responde `200` |
| `https://pacientes.salud.movil` | 443 | Bloqueado |
| `https://consultas.salud.movil` | 443 | Bloqueado |
| `https://monitoreo.salud.movil` | 443 | Bloqueado |

2. Probar también el recurso compartido, que no es una página.

| Sistema | Comando |
|---|---|
| Linux y Mac | `nc -6 -z -w 5 fd5a:fc7e:d716:20::11 445` |
| Windows | `Test-NetConnection fd5a:fc7e:d716:20::11 -Port 445` |

3. En kit01, ver los bloqueos con el mismo comando de P3.

```bash
grep 'fw-drop F-20' /var/log/kitsalud/kit01/firewall.log | tail -5
```

**Mostrar.**

- Los destinos permitidos responden.
- Los bloqueados no responden, y los intentos aparecen en el log con direcciones IPv6.

**Explicar.** Todo está bloqueado salvo lo que tiene una regla. Desde la Comunidad solo se permite DHCP, DNS, hora, el portal y comunidad01 por 80 y 443. Los destinos de la lista están en dos equipos distintos, y la regla es por equipo y por puerto. Es la misma política de IPv4, en la misma tabla de nftables.

## P11 Restauración

**Red.** Un equipo en `SaludMovil-Clinica` con el recurso `archivos` abierto como `SALUD\ana.rojas`, y la laptop Fedora con NetBird.

Esta es la única prueba con script, porque restaurar toca tres equipos. Usa el archivo `prueba-p11.txt` y una tabla de prueba, sin tocar datos reales. El disco USB debe estar conectado a kit01.

1. En el recurso, mostrar `prueba-p11.txt`.
2. En la Fedora, desde `docs/pruebas`, iniciar la prueba.

```bash
./scripts/P11-restauracion.sh
```

3. El script hace una copia y pregunta si sigue. Responder `s`.
4. Cuando se detenga, actualizar el recurso. El archivo ya no está.
5. Presionar Enter. El script restaura desde el disco.
6. Actualizar el recurso. El archivo volvió.

**Mostrar.**

- El archivo desaparece y vuelve igual.
- El script termina con `0 con falla`.

**Explicar.** kit01 extrae las copias de las VMs, y ellas no tienen la clave del repositorio. La copia es semanal, cifrada, y el disco solo se monta mientras se usa.

## P12 Reinicio

**Red.** Equipo de administración, con **Estado del kit** abierto. Durante unos 45 s no hay DHIS2, biblioteca, videos ni archivos.

1. En kit01, reiniciar las dos VMs.

```bash
virsh -c qemu:///system reboot clinica01
virsh -c qemu:///system reboot comunidad01
```

2. Mirar **Problemas ahora** y **Qué está fallando** en Grafana sin tocar nada. Los servicios pasan a rojo y vuelven solos.
3. Abrir el tablero **Recursos de los equipos** y mostrar **Encendido desde hace** en las dos VMs.
4. Abrir `https://pacientes.salud.movil` desde la Clínica.

**Mostrar.**

- Todo vuelve a verde en unos 45 s sin intervención. El estado de los servicios del portal hace lo mismo.
- Las VMs muestran que acaban de arrancar.

**Explicar.** El arranque automático de libvirt, systemd y la política de reinicio de los contenedores. El orden entre aplicaciones lo resuelven sus reintentos.

## P13 Diagnóstico

**Qué demuestra.** Se daña un servicio a propósito y se ve quién se entera y cómo se encuentra la causa. Se usa la biblioteca porque cualquiera entiende la falla.

**Red.** Equipo de administración con **Estado del kit** abierto, y un equipo en `SaludMovil-Comunidad` con el menú de `http://portal.salud.movil` abierto.

| Momento | En el portal | En Grafana |
|---|---|---|
| Antes | Todos los servicios funcionan | **Problemas ahora** en 0 |
| Al detener la biblioteca | Antes de 30 s, Biblioteca de salud en rojo y aviso al personal | Cerca de 40 s después, biblioteca en **Qué está fallando** |
| Al arrancarla | Verde otra vez | Cerca de 20 s después, **Problemas ahora** en 0 |

1. Mostrar los dos en verde.
2. En kit01, entrar a comunidad01 y detener la biblioteca.

```bash
ssh kitsalud@10.20.20.12
sudo docker stop kiwix-kiwix-1
```

3. En el cliente, tocar **Biblioteca de salud**. No abre, y el usuario no sabe por qué.
4. Volver al menú y recargar la página. Aparece **Un servicio tiene problemas**, con la biblioteca en rojo y **Avise al personal de la brigada**.
5. Esperar el rojo en Grafana y leer en **Qué está fallando** el servicio y el equipo.
6. En comunidad01, buscar la causa. `kiwix-kiwix-1` sale como `Exited` y los demás siguen `Up`.

```bash
sudo docker ps -a
```

7. Explicar el impacto, que es solo la biblioteca. Mostrar que Videos sigue funcionando y que DHIS2 no se enteró.
8. Arreglar la falla.

```bash
sudo docker start kiwix-kiwix-1
exit
```

9. Esperar el verde en Grafana y en el portal, y abrir la biblioteca.

**Mostrar.**

- La comunidad ve el problema sin ayuda, y sabe que debe avisar.
- El personal ve qué servicio y qué equipo fallaron.
- El servicio vuelve sin tocar nada más.

**Explicar.** Las dos vistas salen de las mismas sondas. El portal muestra verde si todo responde, amarillo si responde a medias, por ejemplo solo IPv4, y rojo si no responde. Una falla se localiza con el panel primero, el estado del servicio después y los logs al final.

## Publicación de contenido

**Qué demuestra.** Lo que ve la comunidad depende del dominio. El personal sube material con su usuario y llega a Jellyfin, sin que la comunidad toque la red clínica.

**Red.** Un equipo en `SaludMovil-Clinica`, el equipo de administración y un equipo en `SaludMovil-Comunidad`.

1. Abrir el recurso `contenido` con `SALUD\ana.rojas`, igual que en P7. En Windows, `\\archivos.salud.movil\contenido`. En Linux y Mac, `smb://archivos.salud.movil/contenido`.
2. Copiar un audio MP3 o un video MP4 corto a la carpeta `comunidad`.
3. Esperar 2 minutos. Lo recién modificado no se publica, porque podría seguir subiendo.
4. En kit01, publicar sin esperar el ciclo de 10 minutos.

```bash
ssh -t kitsalud@10.20.20.11 sudo systemctl start publicacion.service
```

5. En la Comunidad, abrir **Videos** con el usuario `comunidad`, entrar a la biblioteca **Comunidad** y reproducirlo. Aparece cerca de un minuto después.
6. Borrar el archivo del recurso. La siguiente publicación lo quita de Jellyfin.

**Mostrar.**

- El archivo que subió `ana.rojas` lo reproduce un celular de la Comunidad.
- Desde la Comunidad, el recurso `contenido` sigue bloqueado.

**Explicar.** Solo los grupos `clinicos` y `admins` pueden escribir en `contenido`. Cada 10 minutos, clinica01 copia las carpetas `salud`, `comunidad` y `zim` a comunidad01, con un usuario que solo puede escribir ahí. Así la comunidad recibe contenido sin tener ningún camino hacia clinica01. Lo mismo vale para los archivos ZIM de la biblioteca.
