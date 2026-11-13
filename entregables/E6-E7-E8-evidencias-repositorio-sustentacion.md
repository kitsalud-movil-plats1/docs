<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Evidencias, repositorio técnico y sustentación

**Proyecto final - Plataformas I - 2026-2** · Organización `kitsalud-movil-plats1`

Este documento junta las **evidencias de las pruebas (E6)**, el **repositorio técnico (E7)** y la **sustentación y demostración (E8)**. Van juntos porque dependen uno del otro. Cada prueba se ejecuta con un script del repositorio, y la demostración en vivo repitió esas mismas pruebas.

<div class="salto"></div>

# Parte 1. Evidencias de las pruebas (E6)

Las trece pruebas de aceptación se cumplieron en el kit real, en IPv4 y en IPv6. Para cada una están el criterio del enunciado, las capturas que lo muestran y una interpretación corta del resultado.

| Prueba | Qué demuestra | Resultado |
|---|---|---|
| P1 | Un cliente de la Comunidad recibe IPv4, IPv6, DNS y gateway | Aprobada |
| P2 | Los servicios se encuentran por nombre, con registros A y AAAA | Aprobada |
| P3 | Un invitado no llega a lo clínico ni a la administración | Aprobada |
| P4 | Un invitado usa la biblioteca, los videos y el formulario | Aprobada |
| P5 | Un cliente nuevo va al portal cautivo | Aprobada |
| P6 | El personal registra y consulta un paciente | Aprobada |
| P7 | Los usuarios del directorio entran a los recursos de su grupo | Aprobada |
| P8 | Los equipos toman la hora de kit01 | Aprobada |
| P9 | Sin Internet, lo local sigue funcionando | Aprobada |
| P10 | Por IPv6 se permite lo público y se bloquea lo clínico | Aprobada |
| P11 | Un archivo borrado se recupera de la copia | Aprobada |
| P12 | Los servicios vuelven solos después de un reinicio | Aprobada |
| P13 | Una falla se localiza con el monitoreo y los logs | Aprobada |

## 1. P1. Cliente comunitario

**Criterio.** El cliente obtiene IPv4, IPv6, DNS y gateway, y puede identificar su configuración.

<div class="captura"><img src="../evidencias/capturas/P01-cliente.png" alt="P01-cliente"></div>
<p class="pie-captura">Configuración que recibió un cliente de la red Comunidad y ping a su gateway en las dos familias.</p>

<div class="captura"><img src="../evidencias/capturas/P01-cliente-kea.png" alt="P01-cliente-kea"></div>
<p class="pie-captura">El mismo préstamo visto en el log de Kea en kit01.</p>

**Interpretación.** Kea entregó una dirección del rango de la Comunidad, el gateway `10.20.40.1` y el DNS del kit. Por IPv6, el cliente armó su dirección con el prefijo que anuncia radvd, su ruta por defecto va a `fe80::1` y el DNS IPv6 llegó por DHCPv6. Un equipo nuevo queda listo sin configurar nada, y como sus DNS son los del kit, los nombres de `salud.movil` resuelven desde el primer momento.

## 2. P2. DNS

**Criterio.** Se resuelve por nombre un servicio con registros A y AAAA y se accede sin escribir la IP.

<div class="captura"><img src="../evidencias/capturas/P02-dns.png" alt="P02-dns"></div>
<p class="pie-captura">Registros A y AAAA de los servicios, respuesta autoritativa, nombre inverso y acceso por nombre en las dos familias.</p>

**Interpretación.** Cada servicio tiene el mismo nombre para IPv4 y para IPv6, y el DNS del kit responde como autoridad de `salud.movil` (bandera `aa`). La biblioteca abre por su nombre en las dos familias, así que nadie tiene que recordar direcciones, y si un servicio cambia de equipo solo cambia su registro.

## 3. P3. Aislamiento

**Criterio.** Un cliente de invitados intenta acceder a un servicio clínico o de administración y la conexión queda bloqueada.

<div class="captura"><img src="../evidencias/capturas/P03-aislamiento.png" alt="P03-aislamiento"></div>
<p class="pie-captura">Un invitado con el portal aceptado intenta llegar a DHIS2, a los archivos, a Grafana y al SSH de kit01, y cada intento queda en el log del firewall.</p>

**Interpretación.** Ninguna conexión se abre, en ninguna de las dos familias. El bloqueo está en kit01, que es el único router entre las redes, así que no depende de que los servicios pidan contraseña. Cada intento queda registrado con su origen, su destino y la etiqueta `fw-drop F-20`.

## 4. P4. Acceso público local

**Criterio.** El mismo cliente puede acceder a la biblioteca y al formulario locales según la política definida.

<div class="captura"><img src="../evidencias/capturas/P04-biblioteca-articulo.png" alt="P04-biblioteca-articulo"></div>
<p class="pie-captura">Un artículo de la Wikipedia médica, abierto desde la red Comunidad.</p>

<div class="captura"><img src="../evidencias/capturas/P04-videos.png" alt="P04-videos"></div>
<p class="pie-captura">Jellyfin con el usuario comunidad, sin contraseña.</p>

<div class="captura"><img src="../evidencias/capturas/P04-formulario-codigo.png" alt="P04-formulario-codigo"></div>
<p class="pie-captura">El formulario de prerregistro entrega su código.</p>

<div class="captura"><img src="../evidencias/capturas/P04-base-clinica01.png" alt="P04-base-clinica01"></div>
<p class="pie-captura">El prerregistro quedó en la base de clinica01, y comunidad01 no tiene base propia.</p>

**Interpretación.** Después del portal, un invitado usa todos los servicios públicos. El formulario vive en comunidad01, pero los datos quedan en clinica01, porque quien escribe en la base es comunidad01 con un usuario que solo puede insertar. El invitado nunca llega a clinica01.

## 5. P5. Portal cautivo

**Criterio.** Un cliente nuevo es redirigido al portal cautivo.

<div class="captura"><img src="../evidencias/capturas/P05-portal-condiciones.png" alt="P05-portal-condiciones"></div>
<p class="pie-captura">Un cliente nuevo pide una página externa y termina en las condiciones del portal.</p>

<div class="captura"><img src="../evidencias/capturas/P05-portal-menu.png" alt="P05-portal-menu"></div>
<p class="pie-captura">Después de aceptar, el menú con los servicios y su estado.</p>

<div class="captura"><img src="../evidencias/capturas/P05-portal-kit01.png" alt="P05-portal-kit01"></div>
<p class="pie-captura">En kit01, la MAC del cliente queda autorizada por 8 horas.</p>

**Interpretación.** Sin aceptar, cualquier página por HTTP lleva al portal. Al aceptar, kit01 agrega la MAC del equipo a un set de nftables por 8 horas, y como el set está en la misma tabla para IPv4 e IPv6, la autorización vale para las dos familias. El portal vive en kit01, así que funciona aunque no haya Internet.

## 6. P6. Aplicación clínica

**Criterio.** Un usuario autorizado accede al sistema de pacientes y registra o consulta un dato.

<div class="captura"><img src="../evidencias/capturas/P06-dhis2-registro.png" alt="P06-dhis2-registro"></div>
<p class="pie-captura">Paciente ficticio registrado por ana.rojas en el programa «Atención primaria».</p>

<div class="captura"><img src="../evidencias/capturas/P06-dhis2-lista.png" alt="P06-dhis2-lista"></div>
<p class="pie-captura">carlos.perez, otra cuenta del personal clínico, ve el mismo paciente.</p>

<div class="captura"><img src="../evidencias/capturas/P06-consulta-prerregistros.png" alt="P06-consulta-prerregistros"></div>
<p class="pie-captura">En la consulta de prerregistros aparece el código que se envió en P4.</p>

**Interpretación.** El personal clínico registra y consulta pacientes con su propia cuenta, y lo que registra una persona lo encuentra otra del mismo grupo. La consulta de prerregistros entra con el usuario del dominio y muestra lo que la comunidad envió desde el formulario, lo que cierra el flujo completo del prerregistro.

## 7. P7. Identidad

**Criterio.** Un usuario del directorio inicia sesión en al menos un recurso administrativo.

<div class="captura"><img src="../evidencias/capturas/P07-smb.png" alt="P07-smb"></div>
<p class="pie-captura">ana.rojas (clinicos) entra al recurso archivos por IPv4 y por IPv6, y laura.gomez (admins) es rechazada.</p>

<div class="captura"><img src="../evidencias/capturas/P07-grafana-laura.png" alt="P07-grafana-laura"></div>
<p class="pie-captura">laura.gomez entra a Grafana con su usuario del dominio.</p>

<div class="captura"><img src="../evidencias/capturas/P07-grafana-ana.png" alt="P07-grafana-ana"></div>
<p class="pie-captura">ana.rojas no puede entrar a Grafana.</p>

**Interpretación.** Una misma cuenta del directorio sirve en varios recursos, y cada recurso deja entrar solo al grupo que corresponde. El personal clínico abre los archivos y no la consola de monitoreo, y la administración al revés. El recurso exige SMB3 con cifrado.

## 8. P8. Tiempo

**Criterio.** Dos o más nodos muestran sincronización con el servicio NTP interno.

<div class="captura"><img src="../evidencias/capturas/P08-tiempo.png" alt="P08-tiempo"></div>
<p class="pie-captura">kit01 sirve la hora y las dos VMs y un cliente de la Comunidad la toman de él.</p>

**Interpretación.** Los equipos usan a kit01 como fuente (`^*`), con diferencias de microsegundos, y lo consultan tanto por IPv4 como por IPv6. Una sola hora importa porque Kerberos rechaza a un equipo con más de 5 minutos de diferencia con el dominio, y porque así los logs de todos los equipos se pueden ordenar para seguir una falla.

## 9. P9. Pérdida de Internet

**Criterio.** Se desconecta la salida externa y los servicios locales esenciales continúan disponibles.

<div class="captura"><img src="../evidencias/capturas/P09-sin-internet.png" alt="P09-sin-internet"></div>
<p class="pie-captura">Con la salida a Internet cortada, los nombres externos fallan y lo local sigue respondiendo. Al quitar el corte, todo vuelve solo.</p>

<div class="captura"><img src="../evidencias/capturas/P09-portal-sin-internet.png" alt="P09-portal-sin-internet"></div>
<p class="pie-captura">Sin Internet, un cliente de la Comunidad que pide una página externa llega al portal.</p>

<div class="captura"><img src="../evidencias/capturas/P09-dhis2-sin-internet.png" alt="P09-dhis2-sin-internet"></div>
<p class="pie-captura">DHIS2 funcionando sin Internet.</p>

**Interpretación.** kit01 detectó el corte en menos de un minuto. Los nombres de Internet dejaron de resolver y, para la Comunidad, cualquier nombre externo llevó al portal, que es lo que hace que el celular lo abra solo. El DNS del kit, la hora, DHIS2, la biblioteca y el registro siguieron funcionando, porque todo lo esencial vive dentro del kit.

## 10. P10. Firewall IPv6

**Criterio.** Se realizan una prueba de acceso permitido y otra de acceso bloqueado mediante IPv6.

<div class="captura"><img src="../evidencias/capturas/P10-firewall-ipv6.png" alt="P10-firewall-ipv6"></div>
<p class="pie-captura">Por IPv6, desde la Comunidad, la biblioteca y el registro responden y DHIS2 queda bloqueado.</p>

**Interpretación.** Los dos destinos están en la misma red de servidores, y uno responde mientras el otro queda bloqueado, así que la regla es por equipo y por puerto. Es la misma política que en IPv4, escrita en la misma tabla. Un firewall que solo filtrara IPv4 dejaría pasar a un invitado a clinica01 por IPv6.

## 11. P11. Restauración

**Criterio.** Se elimina o modifica un recurso y se recupera desde un backup o snapshot.

<div class="captura"><img src="../evidencias/capturas/P11-restauracion.png" alt="P11-restauracion"></div>
<p class="pie-captura">Copia, borrado del archivo, restauración con restic desde el disco USB y comprobación final.</p>

**Interpretación.** El archivo volvió con el mismo contenido (mismo sha256), el mismo dueño del dominio, los mismos permisos y la misma ACL, y el usuario lo volvió a abrir por SMB. La copia la saca kit01 desde las VMs, que no tienen la clave del repositorio, y el disco solo se monta mientras se usa.

## 12. P12. Reinicio

**Criterio.** Se reinicia un equipo y los servicios críticos se activan sin intervención manual.

<div class="captura"><img src="../evidencias/capturas/P12-reinicio.png" alt="P12-reinicio"></div>
<p class="pie-captura">Las dos VMs se reinician a la vez y sus servicios vuelven solos.</p>

<div class="captura"><img src="../evidencias/capturas/P12-grafana-recursos.png" alt="P12-grafana-recursos"></div>
<p class="pie-captura">En Grafana, las dos VMs recién encendidas.</p>

**Interpretación.** Las VMs volvieron sin que nadie arrancara nada. PostgreSQL registró un cierre limpio y no tuvo que recuperar datos. Lo que lo hace posible es el arranque automático de libvirt, systemd y la política de reinicio de los contenedores, con reintentos que resuelven el orden entre aplicaciones.

## 13. P13. Diagnóstico

**Criterio.** Al simular una falla, se usan logs y comandos para localizarla y explicar el impacto.

<div class="captura"><img src="../evidencias/capturas/P13-diagnostico.png" alt="P13-diagnostico"></div>
<p class="pie-captura">Se detiene la biblioteca, Prometheus lo detecta, el log central registra la parada, docker ps muestra la causa y al arrancarla las alertas se apagan.</p>

<div class="captura"><img src="../evidencias/capturas/P13-grafana-falla.png" alt="P13-grafana-falla"></div>
<p class="pie-captura">Lo que ve el personal en el tablero.</p>

<div class="captura"><img src="../evidencias/capturas/P13-grafana-que-falla.png" alt="P13-grafana-que-falla"></div>
<p class="pie-captura">El panel «Qué está fallando», con el servicio, el equipo y la familia.</p>

<div class="captura"><img src="../evidencias/capturas/P13-portal-falla.png" alt="P13-portal-falla"></div>
<p class="pie-captura">Lo que ve la comunidad en el portal.</p>

**Interpretación.** La falla se localiza en tres pasos, primero el panel, después el estado del servicio y al final el log. El impacto es acotado. La comunidad pierde la biblioteca, mientras los videos, el formulario y la atención clínica siguen normales. Separar los servicios por VM y por contenedor también separa las fallas.

<div class="salto"></div>

# Parte 2. Repositorio técnico (E7)

<div class="diagrama"><img src="../diagramas/mapa-repositorios.png" alt="Mapa del repositorio técnico"></div>

Todo el kit está en la organización de GitHub `kitsalud-movil-plats1`, repartido en siete repositorios por responsabilidad. Así cada componente se puede cambiar y revisar sin tocar los demás.

| Repositorio | Qué contiene |
|---|---|
| [`platform`](https://github.com/kitsalud-movil-plats1/platform) | El punto de entrada de Ansible (inventario, vault cifrado y playbooks) y los roles de la base de kit01, las VMs, BIND9, Chrony, NUT, la CA, Samba AD, la publicación de contenido, las copias y la actualización |
| [`network`](https://github.com/kitsalud-movil-plats1/network) | La red de kit01 (netplan, nftables, Kea, radvd y el portal cautivo), la configuración del switch y la revisión del punto de acceso |
| [`apps`](https://github.com/kitsalud-movil-plats1/apps) | Los stacks de Docker Compose de clinica01 y comunidad01 y el código de las dos aplicaciones propias (formulario y consulta de prerregistros) |
| [`observability`](https://github.com/kitsalud-movil-plats1/observability) | Prometheus con sus alertas, los paneles de Grafana y el receptor central de logs |
| [`docs`](https://github.com/kitsalud-movil-plats1/docs) | Documento de arquitectura, entregables, diagramas y los scripts de las pruebas P1-P13 |
| [`workspace`](https://github.com/kitsalud-movil-plats1/workspace) | Reglas de trabajo, estado del proyecto, fichas de los equipos y el laboratorio virtual |
| [`.github`](https://github.com/kitsalud-movil-plats1/.github) | Perfil de la organización y plantillas de issues y pull requests |

| Artefacto | Dónde está |
|---|---|
| Playbooks | `platform/ansible/playbooks/` |
| Roles de Ansible | `<repositorio>/ansible/roles/`, uno por servicio |
| Variables (direcciones, nombres, versiones) | `platform/ansible/inventarios/kit/group_vars/all/`, definidas una sola vez |
| Reglas del firewall | `network/kit01/nftables/` |
| Configuración del switch | `network/switch/sw01.rsc` |
| Stacks de contenedores | `apps/clinica01/` y `apps/comunidad01/`, con la versión de cada imagen fija |
| Paneles y alertas del monitoreo | `observability/grafana/` y `observability/prometheus/` |
| Scripts de las pruebas | `docs/pruebas/scripts/` |
| Clonar todo el proyecto | `workspace/scripts/clonar-repos.sh` |

Los roles de cada componente viven en su propio repositorio y `platform/ansible` los encuentra por su posición, así que los repositorios se clonan uno al lado del otro con el script de `workspace`.

**Contraseñas.** Ningún repositorio guarda contraseñas. Los secretos están en un vault de Ansible cifrado con AES-256, y en el repositorio solo está `vault.example.yml` con los nombres de las claves. La contraseña que abre el vault solo existe en las máquinas de control. Las aplicaciones reciben su `.env` generado desde el vault, y en el repositorio solo está el `.env.example`. Se comprobó con un script que busca cada valor del vault en el historial completo de todos los repositorios, con 0 coincidencias.

<div class="salto"></div>

# Parte 3. Sustentación y demostración (E8)

La sustentación tuvo dos partes. Primero una presentación de las decisiones de diseño (el router en el host Ubuntu, las dos VMs separadas por público, la segmentación con dos VLAN y una red de servidores virtual, IPv4 e IPv6 con las mismas reglas y el respaldo en modo extracción), con su fuente en [Figma Slides](https://www.figma.com/slides/cOAeR1yge27oJDGAsPXdgd). Después la demostración en vivo de las trece pruebas, siguiendo el guion de `docs/sustentacion/guion-demostracion.pdf`, que tiene para cada prueba la red, los pasos, lo que se muestra y lo que se explica.

En la demostración se usaron un celular en cada SSID, una laptop en la red de la Clínica y un equipo por cable en el puerto de administración del switch. P9 se mostró desconectando el cable de Internet, y P13 deteniendo la biblioteca para ver cómo la detectan Grafana y el portal.
