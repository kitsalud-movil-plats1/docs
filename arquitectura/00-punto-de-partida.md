<img src="../assets/logo-icesi.png" alt="Universidad Icesi" class="logo" width="160">

# Kit móvil de atención primaria en salud

## Documento de arquitectura inicial (punto de partida) - v0.3

**Proyecto final - Plataformas I - 2026-2** · Organización: `kitsalud-movil-plats1`

Este documento fija las decisiones iniciales de diseño del kit: tecnologías por servicio, recursos necesarios, topología física y lógica, segmentación, direccionamiento IPv4/IPv6, nombres DNS, supuestos y riesgos. Es la base para la arquitectura (E1) y se irá actualizando por medio de pull requests en el repositorio `docs`. Cada decisión tiene un identificador (`D-xx`), cada supuesto (`S-xx`) y cada pregunta abierta (`Q-xx`), para poder referenciarlos desde issues y el tablero Kanban. Los cambios entre versiones están en la sección 16.

## 1. Contexto y alcance

Una brigada de salud debe desplegar en sitio una infraestructura pequeña que preste servicios clínicos, administrativos y comunitarios **sin depender de Internet**. El kit se compone de uno o más nodos de cómputo con virtualización, un switch administrable y un punto de acceso Wi-Fi. El nodo de referencia es un mini PC. Como el equipo exacto no está confirmado, el diseño también permite repartir las VMs entre el mini PC y laptops del grupo, o usar solo laptops (sección 10). La alimentación segura (UPS) se incluye en el diseño de forma lógica, porque no se cuenta con el equipo físico. El enlace a Internet del sitio es un recurso opcional; en el laboratorio se simula con un router MikroTik conectado a la red de la universidad.

El criterio que guía el diseño es el del enunciado: construir una plataforma **pequeña, segura, reproducible y útil**, no reunir la mayor cantidad de tecnologías. Por eso se usan los cuatro segmentos que pide el enunciado, cinco VMs y, para cada requisito, la herramienta más simple que lo cumple. Los recursos se fijan por VM y no por equipo, así se sabe cuánto hardware hace falta con cualquier combinación de equipos.

**Dentro del alcance de esta versión:**

- Diseño lógico y físico, segmentación, plan IPv4/IPv6 y nombres de servicio.
- Selección de tecnologías por requisito (R1-R12) y su relación con las pruebas (P1-P13).
- Catálogo de VMs con sus recursos, perfiles de despliegue según el hardware disponible y dimensionamiento (cómputo, almacenamiento, red y energía).
- Estructura de la organización y de los repositorios.

**Fuera del alcance de esta versión:** configuración detallada de cada servicio (E2), guía de operación (E3), matriz de seguridad definitiva (E4) y tablero Kanban.

## 2. Requerimientos y trazabilidad

### 2.1 Requisitos técnicos

La columna "Componente" indica el rol que presta el servicio. La sección 10.1 indica en qué VM corre cada rol.

| # | Requisito | Solución propuesta | Componente |
|---|---|---|---|
| R1 | DHCPv4 y provisión IPv6 | Kea DHCPv4 de OPNsense con reservas; RA con SLAAC + RDNSS; DHCPv6 stateless en clínica | fw01 |
| R2 | DNS interno dual-stack | BIND9 autoritativo para `salud.movil` (A, AAAA, PTR v4/v6), recursivo solo para redes internas | infra01 |
| R3 | NTP | Chrony como servidor (`ntp.salud.movil`), `local stratum 10` sin Internet; el resto de nodos sincroniza contra él | infra01 |
| R4 | Firewall y segmentación | VLAN 802.1Q + reglas OPNsense por interfaz, default deny, reglas espejo IPv4/IPv6 | fw01, sw01 |
| R5 | Portal cautivo | Captive Portal de OPNsense en VLAN 40 (aceptación de condiciones) | fw01 |
| R6 | Aplicación de pacientes | DHIS2 (Docker) + PostgreSQL, con cuentas locales de DHIS2 y heap de la JVM limitado (10.1) | apps01 |
| R7 | Portal de literatura | Kiwix-serve con archivos ZIM de salud (leídos por NFS desde files01). La biblioteca médica en español ocupa menos de 1 GB | web01 |
| R8 | Formularios de prerregistro | App propia ligera (FastAPI/Flask). Datos en PostgreSQL de apps01; solo el personal clínico autenticado en AD los consulta | web01, apps01 |
| R9 | Almacenamiento compartido | SMB (Samba, autenticación AD) para documentos y exportaciones; NFS de solo lectura para contenido ZIM | files01 |
| R10 | Identidad centralizada | Samba AD DC (`ad.salud.movil`); integra SMB, Grafana y la vista de consulta de formularios | dc01 |
| R11 | Backups y restauración | restic cifrado: cada VM envía sus datos a un rest-server en modo append-only, con el repositorio en un disco USB distinto del principal; dumps de BD y configuraciones; retención 7d/4s/3m | files01, disco USB |
| R12 | Registros y monitoreo | Prometheus (node y blackbox exporters) y Grafana; logs centralizados con rsyslog | mon01 |

### 2.2 Pruebas de aceptación: cómo se demostrarán

| # | Prueba | Evidencia prevista |
|---|---|---|
| P1 | Cliente comunitario | `ip a`, `ip -6 route`, `resolvectl status` / `ipconfig /all` en un cliente de VLAN 40 |
| P2 | DNS | `dig A`/`dig AAAA biblioteca.salud.movil`, acceso por navegador sin IP |
| P3 | Aislamiento | `curl`/`nc` desde VLAN 40 hacia apps01 y fw01 GUI → bloqueado (log del firewall) |
| P4 | Acceso público local | Desde VLAN 40: `biblioteca.salud.movil` y `registro.salud.movil` accesibles |
| P5 | Portal cautivo | Cliente nuevo redirigido a `portal.salud.movil` |
| P6 | Aplicación clínica | Usuario del personal clínico registra y consulta un paciente ficticio en DHIS2 |
| P7 | Identidad | Usuario AD inicia sesión en Grafana y en el recurso SMB `archivos` |
| P8 | Tiempo | `chronyc sources`/`tracking` en dos o más nodos (VMs y nodos físicos) apuntando a infra01 |
| P9 | Pérdida de Internet | Desconectar el RB3011 (VLAN 900): DNS, NTP, DHIS2, formularios y biblioteca siguen funcionando |
| P10 | Firewall IPv6 | `curl -6` permitido (VLAN 40 → web01) y bloqueado (VLAN 40 → apps01). Los dos destinos están en la VLAN 20, así que se ve que la regla es por host |
| P11 | Restauración | Borrar un archivo del share o una tabla de prueba y restaurarla con `restic restore` desde el repositorio del disco USB |
| P12 | Reinicio | Reinicio de kvm01: VMs con `autostart` y servicios `systemd`/`restart: unless-stopped` levantan solos. Con varios nodos, los servicios de los demás nodos se reconectan sin intervención (10.4) |
| P13 | Diagnóstico | Falla inducida (p. ej. BIND9 detenido); se localiza con Grafana (sonda blackbox), los logs centralizados en mon01 y `systemctl`/`journalctl` |

### 2.3 Entregables y repositorio responsable

| Entregable | Repositorio |
|---|---|
| E1 Arquitectura, E3 Operación, E4 Matriz de seguridad, E5 Respaldo, E6 Evidencias | `docs` |
| E2 Guía de despliegue | `docs` (narrativa) + README de cada repositorio técnico |
| E7 Repositorio técnico | `network`, `platform`, `apps`, `observability` |
| E8 Sustentación | `docs/sustentacion` |

## 3. Supuestos

| ID | Supuesto | Impacto si es falso |
|---|---|---|
| S-01 | El equipo no está confirmado. El nodo de referencia es un mini PC x86-64 (p. ej. un MinisForum) con 16 GB de RAM o más, SSD de 512 GB, 4 núcleos/8 hilos o más y una NIC Ethernet | Con menos de 16 GB se usa un perfil con laptops (10.3). Con dos NIC, la WAN puede ir directa y no como VLAN 900 |
| S-02 | El laboratorio presta un switch administrable (Cisco SG350X-24 u otro similar, con 802.1Q y al menos 11 puertos) y el MikroTik RB3011 | Usar otro switch 802.1Q; el uplink puede ser directo a la red de la universidad |
| S-03 | Habrá un AP con varios SSID etiquetados en VLAN (802.1Q). El modelo está por definir | Sin multi-SSID, la red clínica inalámbrica pasaría a ser solo cableada |
| S-04 | El uplink del sitio entrega IPv4 por DHCP con NAT. No hay garantía de un prefijo IPv6 global | Si entrega DHCPv6-PD, se agrega GUA (ver 8.1) |
| S-05 | La demostración se hace en el laboratorio; el "sitio remoto" se simula | Ninguno |
| S-06 | La carga esperada es de 5-10 dispositivos del personal y hasta 50 dispositivos simultáneos de la comunidad | Ampliar el pool de invitados a /23 y el AP |
| S-07 | **No se cuenta con UPS física.** La alimentación segura se implementa solo de forma lógica: NUT con el driver `dummy-ups` en kvm01 simula los eventos de la UPS (corte, batería baja) y dispara el apagado ordenado de todos los nodos. Las laptops que actúen como nodos tienen batería propia | Si se consigue una UPS con USB, solo se cambia el driver de NUT; el procedimiento no cambia |
| S-08 | Todo el software es libre. Windows solo aparece como cliente opcional para unirse al dominio | Ninguno |
| S-09 | `salud.movil` es un dominio interno (no es un TLD público), así que no hay certificados públicos | Hace falta una CA interna (D-16) |
| S-10 | Todos los datos de pacientes que se usen son ficticios | Ninguno |
| S-11 | Algunas laptops del grupo pueden actuar como nodos adicionales (kvm02, kvm03) durante el desarrollo y la sustentación: Linux con KVM, puerto Ethernet (integrado o adaptador USB) y sin suspensión | Todo corre en el perfil 1 (un solo nodo), que exige 16 GB |

## 4. Decisiones de diseño

| ID | Decisión | Alternativas descartadas | Justificación |
|---|---|---|---|
| D-01 | Kit = uno o más nodos KVM (kvm01 y, opcionalmente, kvm02 y kvm03) + switch administrable + AP multi-SSID; UPS solo lógica (S-07). Los recursos se fijan por VM y las VMs se reparten según el hardware disponible (perfiles, 10.3) | Diseño atado a un modelo de equipo; un servidor físico por rol | El hardware no está confirmado. Cada VM conserva su IP y su MAC, así que cambiar de perfil no cambia el direccionamiento, el DNS ni el firewall. Es la modularidad que pide el enunciado: los componentes se reemplazan sin rediseñar la solución |
| D-02 | Router/firewall **OPNsense** como VM en router-on-a-stick | MikroTik, pfSense, Linux+nftables | Portal cautivo integrado, reglas v4/v6 en la misma interfaz, Kea/RA/DHCPv6, configuración exportable en XML |
| D-03 | El RB3011 queda **fuera del kit** y actúa como uplink del sitio. El CCR2004 no se usa | CCR2004 como core | OPNsense ya enruta todas las VLAN. Un segundo salto L3 agrega complejidad sin aportar nada. Desconectar el RB3011 sirve como prueba P9 |
| D-04 | Ubuntu Server 24.04 LTS + KVM/libvirt en cada nodo; aplicaciones en Docker Compose dentro de VMs | Proxmox VE, solo Docker | Continuidad con la experiencia del grupo (laboratorios con libvirt); VMs para aislar roles; contenedores para desplegar apps de forma reproducible. Una laptop puede arrancar Ubuntu desde un SSD externo para no tocar su sistema personal |
| D-05 | Identidad: **Samba AD DC** (rol dc01, en la VM infra01 con IP propia) | Windows Server AD, FreeIPA, OpenLDAP | Compatible con AD y LDAP para las apps; liviano; permite unir un cliente Windows |
| D-06 | Pacientes: **DHIS2 con cuentas locales** | OpenMRS; DHIS2 con login LDAP | Es la sugerida por el enunciado y tiene tracker de pacientes e imagen Docker oficial. Con cuentas locales, la aplicación crítica no depende de dc01: si AD falla, el registro de pacientes sigue funcionando. R10 se cumple con SMB, Grafana y formularios |
| D-07 | Formularios: **app propia ligera** en web01, con los datos en PostgreSQL de apps01 | LimeSurvey, formulario DHIS2 | Da control total de dónde se guardan los datos y quién los consulta. web01 no guarda datos: escribe con un usuario que solo tiene permiso de `INSERT`. La consulta la hace el personal del grupo AD `clinicos` |
| D-08 | Biblioteca: **Kiwix-serve** | CMS, sitio estático | Funciona sin conexión y usa contenido médico listo (Wikipedia Médica en español, WikEM) |
| D-09 | Observabilidad: **Prometheus + Grafana**, con logs centralizados por **rsyslog**; sin Loki/Alloy, Alertmanager ni SNMP | Zabbix, Uptime Kuma; Loki + Alloy en cada nodo; Alertmanager, snmp_exporter | El grupo ya conoce Prometheus y Grafana. rsyslog viene instalado en Ubuntu, y fw01, sw01 y ap01 envían syslog de forma nativa: los logs quedan centralizados en mon01 sin un agente por VM. Sin Internet no hay a dónde enviar alertas, así que se revisan en Grafana. fw01 expone métricas con el plugin `os-node_exporter`; sw01 y ap01 se vigilan con ping (blackbox) y syslog. Loki queda como evolución (12.1) |
| D-10 | Backups con **restic** cifrado: cada VM envía sus datos a un **rest-server en modo append-only** (rol files01), con el repositorio en un disco USB | restic desde el host (v0.2); NAS, solo snapshots; copia externa con rclone | No depende del nodo donde corre cada VM. En modo append-only, una VM comprometida no puede borrar los backups; la retención (`forget`/`prune`) se aplica solo desde files01. El disco USB es otro medio y se puede desconectar. Se respaldan datos y configuraciones, no imágenes de VM: las VMs se reconstruyen desde los repositorios técnicos. La copia externa cuando haya Internet queda documentada como evolución, porque el enunciado no la exige |
| D-11 | IPv4 `10.20.<VLAN>.0/24`, gateway `.1` | `192.168.<VLAN>.0/24` | Evita solaparse con el uplink `192.168.88.0/24` y se resume en una sola regla `10.20.0.0/16` |
| D-12 | IPv6 **ULA `fd5a:fc7e:d716::/48`** con un /64 por VLAN; GUA opcional vía DHCPv6-PD | Solo GUA, `2001:db8::/32` | Direcciones estables sin Internet. No se usa `2001:db8::/32` porque es el prefijo reservado para documentación (RFC 3849) |
| D-13 | Organización con repos por dominio: `.github`, `docs`, `network`, `platform`, `apps`, `observability` | Monorepo, un repo por servicio | Da trazabilidad por área, permisos por equipo y PRs pequeños |
| D-14 | WAN de OPNsense como **VLAN 900** sobre el trunk de kvm01 | NIC USB adicional | Funciona con una sola NIC (S-01). Si hay una segunda NIC, se usa directa |
| D-15 | **Sin DMZ.** Los servicios públicos (biblioteca y formularios) van en una VM propia, **web01**, dentro de la VLAN 20 | DMZ en una VLAN 50; publicar desde apps01 | El enunciado pide cuatro segmentos y permite que los invitados accedan a "portales públicos concretos" (sección 6). Los invitados solo alcanzan la IP de web01 en 80/443. Tener web01 como VM aparte permite filtrar por IP en fw01, cosa que no sería posible si todo estuviera en apps01. El riesgo que se acepta está en R-06 |
| D-16 | TLS con la **CA interna de Caddy** (`tls internal`), con una sola raíz compartida por los Caddy de apps01 y web01. La raíz se instala en equipos clínicos y de gestión | HTTP plano, step-ca | Protege credenciales y datos clínicos en tránsito sin agregar otro servicio (ver Q-05 para invitados) |
| D-17 | Credenciales fuera de Git: `.env.example` + `ansible-vault` | Contraseñas en README, sops | Cumple la política de "no contraseñas en texto plano" con una sola herramienta |
| D-18 | **Gestión solo por cable**: no hay SSID en la VLAN 10 | SSID `SaludMovil-Gestion` | Menos superficie de ataque sobre la red de administración y una configuración menos en el AP. El enunciado pide SSID separados para la comunidad y para la red clínica/administrativa |
| D-19 | **Cinco VMs con una IP por rol**: la VM infra01 aloja los roles infra01 y dc01; la VM ops01 aloja files01 y mon01; fw01, apps01 y web01 quedan solas | Siete VMs, una por rol (v0.2); fusionar roles en una sola IP | Las siete VMs de la v0.2 sumaban 28 GB; las cinco caben en un nodo de 16 GB (10.1). Cada rol conserva su IP y su nombre, así que las zonas DNS, la matriz de flujos y los clientes no cambian, y separar un rol en su propia VM más adelante solo requiere mover su IP (12.1). En infra01, BIND9 escucha en la `.10` y Samba en la `.11`, lo que evita el choque en el puerto 53 y conserva la delegación de `ad.salud.movil` |

## 5. Arquitectura física

### 5.1 Inventario del kit

| Equipo | Rol | Notas |
|---|---|---|
| `kvm01` | Nodo principal: hipervisor KVM. Aloja fw01 e infra01 en todos los perfiles | Mini PC en los perfiles 1 y 2; laptop en el perfil 3. SSD con SO y VMs |
| `kvm02`, `kvm03` (opcionales) | Nodos adicionales: hipervisores KVM | Laptops del grupo (perfiles 2 y 3, ver 10.3) |
| Disco USB (128 GB o más) | Repositorio de backups (restic) | Conectado al nodo que aloja ops01 y entregado a esa VM como disco |
| Switch Cisco SG350X-24 (`sw01`) | Conmutación L2, trunk 802.1Q | Alternativa más compacta en R-02 |
| AP multi-SSID (`ap01`) | Wi-Fi con SSID por VLAN | Modelo por definir (S-03) |
| UPS (lógica) | Alimentación segura y apagado controlado | No se cuenta con el equipo. Se simula con NUT `dummy-ups` en kvm01 (ver 12) |
| _Fuera del kit:_ MikroTik RB3011 | Uplink del sitio (NAT a la red de la universidad) | `192.168.88.0/24` |

### 5.2 Conexiones y puertos del switch (preliminar)

| Puerto sw01 | Conectado a | Modo | VLAN |
|---|---|---|---|
| gi1/0/1 | kvm01 (nodo principal) | Trunk | 10, 20, 30, 40, 900 etiquetadas; nativa 999 |
| gi1/0/2 | ap01 | Trunk | 10 nativa (gestión del AP); 30, 40 etiquetadas |
| gi1/0/3 | RB3011 (uplink) | Acceso | 900 |
| gi1/0/4-5 | kvm02, kvm03 (nodos adicionales) | Trunk | 10, 20 etiquetadas; nativa 999. En `shutdown` si el perfil no usa ese nodo |
| gi1/0/6-9 | Estaciones clínicas | Acceso | 30 |
| gi1/0/10-11 | Estaciones de gestión | Acceso | 10 |
| resto | Sin uso | Acceso, `shutdown` | 999 |

Cambiar de perfil solo implica habilitar o deshabilitar gi1/0/4-5. Los nodos adicionales reciben únicamente las VLAN 10 (gestión del nodo) y 20 (VMs de servicio). Las VLAN 30, 40 y 900 solo llegan a kvm01, donde está fw01.

### 5.3 SSID

| SSID | VLAN | Seguridad |
|---|---|---|
| `SaludMovil-Comunidad` | 40 | Abierta + portal cautivo, con aislamiento de clientes |
| `SaludMovil-Clinica` | 30 | WPA3/WPA2-Personal |

La VLAN 10 no tiene SSID: la gestión se hace solo desde los puertos cableados gi1/0/10-11 (D-18).

### 5.4 Diagrama físico

Fuente editable en Lucidchart: <https://lucid.app/lucidchart/6f4fcfbd-f4c1-4b09-b94e-0514d72603b5/edit>. La especificación versionada está en `diagramas/diagrama-fisico.lucid.json`.

<div class="diagrama-fisico"><img src="../diagramas/diagrama-fisico.png" alt="Diagrama físico del kit"></div>

## 6. Arquitectura lógica

Fuente editable del diagrama en Lucidchart: <https://lucid.app/lucidchart/588a47ec-e999-4e1e-8f25-3931e7f353d8/edit>. La especificación versionada está en `diagramas/diagrama-logico.lucid.json`. Los dos diagramas se regeneran con `tools/build-diagrams.sh`.

<div class="diagrama"><img src="../diagramas/diagrama-logico.png" alt="Diagrama lógico del kit"></div>

**Router-on-a-stick.** La NIC de kvm01 es un trunk 802.1Q hacia sw01. En kvm01, un bridge Linux con VLAN (`br0`, `vlan_filtering=1`) entrega el trunk completo a fw01, y cada VM de servicio queda como puerto de acceso en su VLAN. OPNsense es el único gateway L3: cada VLAN tiene su interfaz con `.1` / `::1`. Los nodos adicionales usan el mismo bridge, pero su trunk solo lleva las VLAN 10 y 20. Una VM de la VLAN 20 que corre en kvm02 llega a su gateway (fw01, en kvm01) a través del switch.

**Servicios públicos sin DMZ (D-15).** web01 está en la VLAN 20, pero es el único servidor al que pueden llegar los invitados, y solo por 80/443. El tráfico de web01 hacia apps01, files01 y dc01 no pasa por fw01, porque va dentro de la misma VLAN; aunque las VMs estén en nodos distintos, el switch lo conmuta en capa 2. Ese tráfico se controla en cada servidor (ver sección 11 y R-06).

**Dependencias entre servicios (orden de arranque):**

1. Nodos (red, bridges)
2. fw01 (gateway, DHCP, RA)
3. infra01 (DNS y NTP; después el rol dc01, que necesita DNS y tiempo)
4. ops01 (files01: SMB con AD, NFS y repositorio de backups; mon01: Prometheus, Grafana con LDAP y rsyslog)
5. apps01 (PostgreSQL → DHIS2, necesita DNS; no depende de AD)
6. web01 (Caddy, Kiwix con NFS de files01, formularios con BD en apps01 y login AD para la consulta)

Dentro de un nodo, el orden se controla con el `autostart` de libvirt más retardos de arranque, y con `depends_on`/healthchecks en Compose. Entre nodos no hay orden garantizado: cada servicio reintenta hasta que su dependencia responde (10.4).

## 7. Plan IPv4

### 7.1 Segmentos

| VLAN | Nombre | Subred | Gateway | Asignación | Pool DHCP |
|---|---|---|---|---|---|
| 10 | Gestión | 10.20.10.0/24 | 10.20.10.1 | Estática + reservas | 10.20.10.100-119 (solo reservas) |
| 20 | Servidores | 10.20.20.0/24 | 10.20.20.1 | Estática | - |
| 30 | Clínica/Administrativa | 10.20.30.0/24 | 10.20.30.1 | DHCPv4 | 10.20.30.100-199 (lease 8 h) |
| 40 | Comunidad/Invitados | 10.20.40.0/24 | 10.20.40.1 | DHCPv4 | 10.20.40.100-250 (lease 1 h) |
| 900 | WAN (tránsito) | 192.168.88.0/24 | 192.168.88.1 (RB3011) | DHCP del RB3011 | - |
| 999 | Parking | - | - | Sin L3 | - |

**Convención de hosts:** `.1` gateway, `.2-.9` equipos de red y nodos, `.10-.49` servidores, `.100-.250` clientes.

**NAT:** una sola regla de NAT de salida (masquerade) de `10.20.0.0/16` hacia la interfaz WAN. Va aparte del filtrado entre VLAN, que se hace con reglas por interfaz.

### 7.2 Direcciones de infraestructura

Cada rol tiene su propia IP, aunque comparta VM con otro rol (D-19).

| Host / rol | VM | Función | IPv4 | IPv6 |
|---|---|---|---|---|
| fw01 | fw01 | OPNsense (gateway de cada VLAN) | 10.20.X.1 | fd5a:fc7e:d716:X::1 |
| sw01 | - | Switch (gestión) | 10.20.10.2 | fd5a:fc7e:d716:10::2 |
| ap01 | - | AP (gestión) | 10.20.10.3 | fd5a:fc7e:d716:10::3 |
| kvm01 | - | Nodo principal (gestión) | 10.20.10.5 | fd5a:fc7e:d716:10::5 |
| kvm02 | - | Nodo adicional (gestión, opcional) | 10.20.10.6 | fd5a:fc7e:d716:10::6 |
| kvm03 | - | Nodo adicional (gestión, opcional) | 10.20.10.7 | fd5a:fc7e:d716:10::7 |
| infra01 | infra01 | BIND9 + Chrony | 10.20.20.10 | fd5a:fc7e:d716:20::10 |
| dc01 | infra01 | Samba AD DC | 10.20.20.11 | fd5a:fc7e:d716:20::11 |
| files01 | ops01 | Samba SMB + NFS + rest-server (backups) | 10.20.20.12 | fd5a:fc7e:d716:20::12 |
| apps01 | apps01 | DHIS2 + PostgreSQL | 10.20.20.13 | fd5a:fc7e:d716:20::13 |
| mon01 | ops01 | Prometheus, Grafana, rsyslog | 10.20.20.14 | fd5a:fc7e:d716:20::14 |
| web01 | web01 | Caddy, Kiwix, formularios (servicios públicos) | 10.20.20.15 | fd5a:fc7e:d716:20::15 |

## 8. Plan IPv6

### 8.1 Estrategia

- **Prefijo interno:** ULA `fd5a:fc7e:d716::/48`. El Global ID de 40 bits se generó aleatoriamente, como pide la RFC 4193. Es estable y no depende del proveedor, así que el kit funciona igual con o sin Internet.
- **Subredes:** un /64 por VLAN, y el ID de subred es el número de VLAN (`fd5a:fc7e:d716:<VLAN>::/64`). Queda espacio para 65 536 subredes.
- **Servidores:** direcciones estáticas que espejan el último octeto IPv4 (`10.20.20.10` ↔ `fd5a:fc7e:d716:20::10`). Esto facilita la lectura de reglas, zonas DNS y logs.
- **GUA opcional:** si el uplink entrega un prefijo por DHCPv6-PD, OPNsense lo reparte como segundo prefijo solo en las VLAN 20 y 30. Las políticas se escriben sobre alias, no sobre prefijos, así que no cambian.

### 8.2 Asignación por segmento

| VLAN | Prefijo | Mecanismo | Flags RA | DNS |
|---|---|---|---|---|
| 10 | fd5a:fc7e:d716:10::/64 | Estático + SLAAC | M=0, O=0 | RDNSS |
| 20 | fd5a:fc7e:d716:20::/64 | Estático (sin SLAAC en servidores) | M=0, O=0 | Estático |
| 30 | fd5a:fc7e:d716:30::/64 | SLAAC + DHCPv6 stateless (DNS, dominio de búsqueda, NTP) | M=0, O=1 | RDNSS + DHCPv6 |
| 40 | fd5a:fc7e:d716:40::/64 | SLAAC + RDNSS (Android no tiene cliente DHCPv6) | M=0, O=0 | RDNSS |

El DNS anunciado es `fd5a:fc7e:d716:20::10` (infra01), igual que en DHCPv4, donde se anuncia `10.20.20.10`.

### 8.3 Seguridad IPv6

- Las reglas de firewall son **equivalentes en v4 y v6**. Se escriben sobre alias con miembros de ambas familias (p. ej. `H_WEB01 = 10.20.20.15, fd5a:fc7e:d716:20::15`).
- Se permite el ICMPv6 imprescindible (NDP, RA/RS, Packet Too Big, Time Exceeded y Parameter Problem, según la RFC 4890). El eco ICMPv6 solo se permite desde la VLAN 10 y para las pruebas.
- El portal cautivo de OPNsense solo cubre IPv4. Por eso, en la VLAN 40, IPv6 **solo** llega a web01, DNS y NTP. No hay salida a Internet por IPv6 para invitados y así IPv6 no queda como una vía que se salte el portal.
- Se activa RA Guard y DHCPv6 Guard en los puertos de acceso del switch, si el firmware lo soporta, para evitar RA falsos.

## 9. DNS y nombres de servicio

Zona autoritativa `salud.movil` en infra01. Las zonas inversas son `10.20.in-addr.arpa` y `6.1.7.d.e.7.c.f.a.5.d.f.ip6.arpa`. La subzona `ad.salud.movil` se delega a dc01 (Samba AD), que responde en su propia IP aunque comparta VM con infra01. La recursión solo se permite a `10.20.0.0/16` y `fd5a:fc7e:d716::/48`. Los forwarders externos se usan solo cuando hay Internet; sin Internet, las zonas locales siguen respondiendo.

| Nombre | Destino | A | AAAA |
|---|---|---|---|
| `pacientes.salud.movil` | apps01 (DHIS2) | 10.20.20.13 | fd5a:fc7e:d716:20::13 |
| `biblioteca.salud.movil` | web01 (Kiwix) | 10.20.20.15 | fd5a:fc7e:d716:20::15 |
| `registro.salud.movil` | web01 (formularios) | 10.20.20.15 | fd5a:fc7e:d716:20::15 |
| `ntp.salud.movil` | infra01 | 10.20.20.10 | fd5a:fc7e:d716:20::10 |
| `archivos.salud.movil` | files01 | 10.20.20.12 | fd5a:fc7e:d716:20::12 |
| `ns1.salud.movil` | infra01 | 10.20.20.10 | fd5a:fc7e:d716:20::10 |
| `monitoreo.salud.movil` | mon01 (Grafana) | 10.20.20.14 | fd5a:fc7e:d716:20::14 |
| `portal.salud.movil` | fw01 (portal cautivo) | 10.20.40.1 | - |
| `dc01.ad.salud.movil` | dc01 | 10.20.20.11 | fd5a:fc7e:d716:20::11 |
| `fw01`, `sw01`, `ap01`, `kvm01`, `kvm02`, `kvm03` `.salud.movil` | Gestión | 10.20.10.1/.2/.3/.5/.6/.7 | fd5a:fc7e:d716:10::1/2/3/5/6/7 |

## 10. Servicios, recursos y perfiles de despliegue

Los recursos se fijan por VM (10.1). El hardware necesario depende de cómo se repartan las VMs entre los equipos disponibles (10.3).

### 10.1 Catálogo de VMs

| VM | Roles (IP) | SO / runtime | Servicios | vCPU | RAM | Disco |
|---|---|---|---|---|---|---|
| fw01 | fw01 (`.1` en cada VLAN) | OPNsense 26.x | Enrutamiento, filtro v4/v6, NAT, Kea DHCPv4, RA/DHCPv6, portal cautivo, `os-node_exporter` | 2 | 3 GB | 32 GB |
| infra01 | infra01 (`.10`), dc01 (`.11`) | Ubuntu 24.04 | BIND9, Chrony, Samba AD DC | 2 | 1,5 GB | 20 GB |
| apps01 | apps01 (`.13`) | Ubuntu 24.04 + Docker | DHIS2 (heap de 1,5-2 GB), PostgreSQL/PostGIS (DHIS2 y formularios), Caddy | 4 | 5 GB | 60 GB |
| web01 | web01 (`.15`) | Ubuntu 24.04 + Docker | Caddy, Kiwix-serve, app de formularios | 1 | 1 GB | 20 GB |
| ops01 | files01 (`.12`), mon01 (`.14`) | Ubuntu 24.04 + Docker | Samba (miembro del dominio), NFS, rest-server; Prometheus, blackbox exporter, Grafana, rsyslog central | 2 | 2 GB | 20 GB + 50 GB de datos |
| **Total** | | | | **11** | **12,5 GB** | **≈ 200 GB** |

Criterios de las cifras:

- **fw01:** 3 GB es el mínimo que indica la documentación de OPNsense.
- **apps01:** la guía de administración de DHIS2 pide al menos 2 GB para una instancia pequeña, repartidos entre la JVM y PostgreSQL. Para 5-10 usuarios y una base con metadatos mínimos se asignan 5 GB. La cifra se valida con una prueba de humo antes del hito de aplicaciones (R-03).
- **Disco:** los discos son qcow2 con aprovisionamiento delgado y solo ocupan lo que realmente se escribe (≈ 60-80 GB al inicio). Los 50 GB de datos de ops01 cubren el share, los ZIM, las métricas y los logs. Los ZIM ocupan menos de 3 GB: Wikipedia Médica en español pesa 626 MB con imágenes.

Todas las VMs Linux y los nodos físicos llevan `node_exporter`, rsyslog con reenvío a mon01, `chrony` apuntando a `ntp.salud.movil`, SSH solo con llave, cuentas individuales, sin login directo de root y un firewall local (`ufw`) que deniega por defecto el tráfico entrante.

### 10.2 Requisitos de un nodo

| Recurso | Requisito |
|---|---|
| CPU | x86-64 con virtualización (AMD-V/VT-x) activa. En kvm01, 4 núcleos/8 hilos o más |
| RAM | La suma de sus VMs más 1,5 GB para el SO del nodo (servidor sin escritorio) o 3,5 GB (laptop con su escritorio). En equipos con gráficos integrados, reducir en la BIOS la memoria reservada para video |
| Disco | SSD con 30 GB para el SO más los discos de sus VMs |
| Red | Un puerto Ethernet de 1 GbE o más, integrado o adaptador USB, que soporte 802.1Q. El Wi-Fi no sirve para el trunk |
| SO | Linux con KVM/libvirt; Ubuntu 24.04 en los nodos dedicados. Una laptop puede arrancar Ubuntu desde un SSD externo |
| Operación | Conectado a la UPS o al cargador, sin suspensión (tampoco al cerrar la tapa), VMs con `autostart` y cliente NUT |

### 10.3 Perfiles de despliegue

Las VMs son las mismas en todos los perfiles; solo cambia el nodo donde corren. La RAM por nodo incluye el SO del nodo (10.2).

| Perfil | Equipos | kvm01 | kvm02 | RAM usada por nodo |
|---|---|---|---|---|
| 1. Un nodo | Mini PC de 16 GB o más | Todas | - | kvm01: 14 GB |
| 2. Mini PC + laptop | Mini PC de 16 GB + laptop | fw01, infra01, apps01 | web01, ops01 | kvm01: 11 GB · kvm02: 6,5 GB |
| 2b. Mini PC pequeño + laptop | Mini PC de 8 GB + laptop de 16 GB | fw01, infra01 | apps01, web01, ops01 | kvm01: 6 GB · kvm02: 11,5 GB |
| 3. Solo laptops | Dos laptops de 16 GB | fw01, infra01, web01, ops01 | apps01 | kvm01: 11 GB · kvm02: 8,5 GB |

- El perfil 1 es el kit de referencia. Con 16 GB queda un margen de unos 2 GB; con 32 GB, holgado.
- Las cifras de laptop suponen que conserva su escritorio. Si arranca Ubuntu Server sin escritorio, usa 2 GB menos; así, la laptop del perfil 2 puede ser de 8 GB.
- Con una tercera laptop (kvm03), ops01 puede ir en ella para que los backups queden en un equipo distinto del de las VMs que protegen.
- En el switch, cambiar de perfil solo implica habilitar gi1/0/4-5 (5.2).
- Los equipos que actúan como nodos no se usan como clientes en las pruebas. Para P1, P3-P5 y P10 basta un celular en el SSID de comunidad.

### 10.4 Reglas de ubicación

1. **fw01 e infra01 siempre en kvm01**, el nodo más estable (el mini PC, si existe). Sin ellas no hay gateway, DHCP, DNS ni NTP, así que la caída de otro nodo nunca tumba la red. kvm01 es el único nodo cuyo trunk lleva las VLAN 30, 40 y 900.
2. **apps01** va en kvm01 si tiene 16 GB o más; si no, en el nodo con más RAM libre (6 GB o más).
3. **ops01** va en el nodo que tiene conectado el disco USB de backups. Si hay varios nodos, conviene que no comparta nodo con apps01, para que el respaldo de la base de pacientes quede en otro equipo.
4. **Mover una VM de nodo:** apagarla, copiar su disco qcow2 y su definición (`virsh dumpxml` / `virsh define`) y encenderla en el otro nodo. También se puede redesplegar desde los repositorios técnicos y restaurar sus datos del backup. La IP y la MAC viajan con la VM, así que DNS, firewall y monitoreo no cambian.
5. **Arranque entre nodos:** libvirt ordena el arranque solo dentro de cada nodo. Las dependencias entre nodos se resuelven con reintentos: `Restart=on-failure` en systemd, montajes NFS con reintento y healthchecks en Compose.

## 11. Matriz de flujos preliminar

Política por defecto: **denegar todo el tráfico entre VLAN y registrarlo**. Todas las reglas aplican a IPv4 e IPv6, salvo que se indique otra cosa.

Los flujos marcados como _intra-VLAN 20_ no pasan por fw01, porque origen y destino están en la misma VLAN, aunque estén en nodos distintos. Se controlan con el firewall local (`ufw`) de cada servidor y con los permisos de cada servicio (`pg_hba.conf`, exports NFS, grupos de AD). Las reglas de `ufw` se escriben por IP de rol, también cuando dos roles comparten VM.

| ID | Origen | Destino | Puertos | Justificación |
|---|---|---|---|---|
| F-01 | VLAN 10 | Todas las VLAN, fw01, nodos | 22, 443, 8443, ICMP | Administración (SSH, GUI) solo desde gestión |
| F-02 | VLAN 10, 30, 40 | infra01 | 53 tcp/udp, 123/udp | DNS y NTP internos (desde la VLAN 20 es intra-VLAN) |
| F-03 | VLAN 30 | apps01 | 443 | DHIS2 (`pacientes`) |
| F-04 | VLAN 30 | files01 | 445 | Recurso SMB `archivos` |
| F-05 | VLAN 30 | web01 | 443 | Formularios (vista de consulta del personal) y biblioteca |
| F-06 | VLAN 30 | dc01 | 88, 389, 464, 636, 445, 135, 49152-65535 | Solo si se unen equipos al dominio (Q-03) |
| F-07 | VLAN 40 | web01 | 80, 443 | Biblioteca y formularios públicos. **Única excepción** de invitados hacia la VLAN 20 |
| F-08 | VLAN 40 | fw01 | 8000/tcp (portal), 53 | Portal cautivo |
| F-09 | VLAN 40 | Internet | any (solo IPv4, tras autenticarse en el portal) | Conectividad comunitaria |
| F-10 | web01 | apps01 | 5432 | _Intra-VLAN 20._ BD de formularios. `pg_hba.conf` solo acepta a web01, con un usuario que solo tiene permiso de `INSERT` |
| F-11 | web01 | files01 | 2049 | _Intra-VLAN 20._ NFS de solo lectura con el contenido ZIM, exportado solo para web01 |
| F-12 | web01, mon01, files01 | dc01 | 636; files01 además 88, 389, 445, 464 | _Intra-VLAN 20._ LDAPS para la consulta de formularios y Grafana; Kerberos/LDAP para files01 como miembro del dominio |
| F-13 | Todas las VMs y nodos | mon01 | 514/tcp | Envío de logs con rsyslog |
| F-14 | mon01 | Todas las VMs y nodos, fw01 | 9100, 53, 443, ICMP | Scraping de `node_exporter` y sondas blackbox (DNS, HTTPS, ping a sw01 y ap01) |
| F-15 | fw01, sw01, ap01 | mon01 | 514/udp | Syslog de equipos de red (eventos de firewall y DHCP) |
| F-16 | VLAN 20 | Internet | 80, 443 | Actualizaciones de paquetes e imágenes (solo con Internet, R-05) |
| F-17 | infra01 | Internet | 53, 123/udp | Forwarders DNS y fuentes NTP externas |
| F-18 | Todas | Todas | ICMPv6 NDP/PMTU | Funcionamiento de IPv6 (RFC 4890) |
| F-19 | VLAN 40 | VLAN 10, 30, resto de la VLAN 20, fw01 GUI | any | **Bloqueado y registrado** (prueba P3/P10). En la VLAN 20 solo se permiten F-02 y F-07 |
| F-20 | infra01, apps01, web01 | files01 | 8000/tcp (TLS) | _Intra-VLAN 20._ Envío de backups al rest-server (append-only, un usuario por VM) |

## 12. Dimensionamiento y energía (preliminar)

- **Cómputo:** 11 vCPU en total. En el perfil 1 se reparten sobre 8 hilos o más (sobreasignación baja); en los perfiles con laptops, ningún nodo pasa de 7 vCPU. La carga pico esperada es la de DHIS2 durante su arranque y el registro.
- **Memoria:** 12,5 GB para las VMs más el SO de cada nodo; la tabla de 10.3 da la RAM por nodo en cada perfil. **Mínimo 16 GB en un solo nodo; se recomiendan 32 GB** para crecer sin repartir entre equipos.
- **Almacenamiento:** unos 200 GB asignados a VMs (60-80 GB ocupados al inicio) más 30 GB de SO por nodo → SSD de 512 GB en kvm01 (256 GB alcanza, con poco margen). Backups en un disco USB de 128 GB o más: con retención 7d/4s/3m y deduplicación se estima un uso de 10-30 GB, porque se respaldan datos y configuraciones, no imágenes de VM.
- **Clientes:** 5-10 del personal y hasta 50 de la comunidad. El pool de invitados tiene 151 direcciones con lease de 1 h.
- **Red:** trunk de 1 GbE por nodo; los adaptadores USB de las laptops son de 1 GbE, suficiente para esta carga. AP Wi-Fi 5/6 con un mínimo recomendado de 50 clientes simultáneos.

| Equipo | Consumo típico | Pico |
|---|---|---|
| Mini PC | 35 W | 90 W |
| Laptop (nodo) | 20 W | 65 W (cargador) |
| Switch SG350X-24 | 25 W | 30 W |
| AP (PoE/inyector) | 10 W | 15 W |

| Perfil | Consumo total (típico / pico) | Carga sobre la UPS (típica) | Autonomía estimada |
|---|---|---|---|
| 1 | ≈ 70 W / 135 W | ≈ 70 W | 60-90 min |
| 2 y 2b | ≈ 90 W / 200 W | ≈ 70 W (la laptop usa su batería) | 60-90 min; la laptop, según su batería |
| 3 | ≈ 75 W / 175 W | ≈ 35 W (switch y AP) | 2-3 h para la red; cada laptop, según su batería |

**Alimentación segura (implementación lógica).** No se cuenta con UPS física, así que el diseño la trata como un componente lógico:

- **Dimensionamiento de referencia:** para la carga típica de unos 70 W, una UPS de 1000 VA/600 W (unos 200 Wh nominales, de los que se aprovecha cerca del 60 %) daría una **autonomía estimada de 60 a 90 minutos**.
- **Simulación:** en kvm01, NUT usa el driver `dummy-ups` con un archivo de estado. Al cambiar el estado a `OB` (en batería) y luego a `LB` (batería baja), se simulan el corte de energía y la batería baja.
- **Apagado ordenado:** `upsmon` corre en kvm01 como primario y en los nodos adicionales como secundario, y todos ejecutan el mismo script de apagado que se usaría con una UPS real. Cada nodo apaga sus VMs en orden inverso al de arranque (sección 6) y luego se apaga. kvm01 se apaga de último, porque aloja fw01 e infra01.
- **Paso a hardware real:** si se consigue una UPS con USB, solo se cambia el driver de NUT (p. ej. `usbhid-ups`); el procedimiento no cambia.

### 12.1 Crecimiento: qué cambiaría con más usuarios

La v0.2 de este documento describía el diseño a mayor escala. Si el kit atendiera más usuarios:

- **Separar roles en VMs propias:** dc01 sale de infra01 y mon01 sale de ops01, moviendo su IP (D-19). DNS, firewall y clientes no cambian.
- **apps01 a 8-10 GB**, con la memoria repartida por mitades entre la JVM y PostgreSQL, como recomienda la guía de DHIS2.
- **Loki** para consultar logs indexados desde Grafana, a partir del mismo syslog.
- **Pool de invitados a /23** y un segundo AP (S-06).
- **Un nodo de 32-64 GB** o un segundo nodo fijo con un DNS secundario, para quitar el punto único de falla (R-01).

## 13. Riesgos y preguntas abiertas

| ID | Riesgo / pregunta | Mitigación / siguiente paso |
|---|---|---|
| R-01 | kvm01 es un punto único de falla: aloja fw01 e infra01 en todos los perfiles | Backups probados, apagado ordenado y procedimiento de restauración (P11). Documentar un segundo nodo fijo con DNS secundario como evolución (12.1) |
| R-02 | El SG350X-24 es de 1U y pesado para un kit portátil | Alternativa compacta: switch de 8-10 puertos gestionable con PoE (p. ej. SG350-10P o MikroTik CSS/CRS) |
| R-03 | DHIS2 consume mucha RAM | Heap de la JVM limitado a 1,5-2 GB. Prueba de humo antes del hito de aplicaciones: DHIS2 en Docker con límite de 5 GB, midiendo con `docker stats` el consumo y el tiempo de arranque. Si no alcanza, apps01 pasa a un nodo con más RAM (perfil 2) |
| R-04 | Portal cautivo solo IPv4 | Política IPv6 restrictiva en la VLAN 40 (8.3) |
| R-05 | Actualizaciones sin Internet | No se actualiza sin Internet. Las actualizaciones se aplican en base o cuando haya conexión, en una ventana documentada en E3 y con snapshot previo de la VM. Las imágenes Docker usan versión fija y se guardan con `docker save` en el disco USB de backups, para poder reinstalar sin conexión |
| R-06 | web01 atiende a invitados y comparte la VLAN 20 con los servidores internos; su tráfico hacia ellos no pasa por fw01 (D-15) | Firewall local (`ufw`) en cada servidor, con entrada denegada por defecto. `pg_hba.conf` solo acepta a web01, con un usuario de solo `INSERT`. Export NFS de solo lectura y solo para web01. Contenedores sin root. Si el kit crece o atiende más público, los servicios públicos vuelven a una VLAN propia |
| R-07 | Una laptop que actúa como nodo puede no estar disponible (es un equipo personal) y sus VMs se detienen con ella | fw01 e infra01 nunca van en un nodo adicional (10.4). Mover la VM a otro nodo o redesplegarla y restaurar su backup. E3 lista qué VM corre en qué nodo en cada perfil |
| R-08 | Adaptadores USB-Ethernet sin soporte de VLAN o con nombres de interfaz que cambian | Probar temprano en cada laptop (`ip link add link <if> name <if>.20 type vlan id 20`) y fijar el nombre de la interfaz por MAC en netplan |
| R-09 | Samba AD DC y BIND9 en la misma VM (infra01) con IP distintas | Validar en el hito de servicios base: Samba solo en la `.11` (`bind interfaces only`) y BIND9 solo en la `.10`. Si da problemas, pasar a BIND9 con el backend BIND9_DLZ de Samba o devolver dc01 a su propia VM (+1 GB) |
| Q-01 | ¿Qué equipo hay disponible (RAM, disco, NIC)? | Confirmar con el laboratorio (`free -h`, `lsblk`, `ip link`). Define el perfil (10.3) |
| Q-02 | ¿Qué AP hay disponible? | Confirmar; requiere multi-SSID + 802.1Q |
| Q-03 | ¿Se unirá un cliente Windows al dominio? | Si es así, habilitar F-06 |
| Q-04 | ¿El SSID clínico usará 802.1X (RADIUS contra AD)? | **Cerrada:** no. Se usa WPA3/WPA2-Personal; 802.1X queda fuera del alcance |
| Q-05 | ¿TLS para invitados? `registro` maneja datos personales | Opciones: HTTPS con CA interna (con advertencia en el navegador) o HTTP solo para la biblioteca. Decidir en el hito de Wi-Fi y seguridad |
| Q-06 | ¿Acceso del docente a los repositorios? | Los repositorios son públicos, así que el docente puede leerlos sin invitación. Invitarlo a la organización solo si debe comentar o revisar PRs. Por ser públicos, se refuerza la regla de cero secretos (D-17) |
| Q-07 | ¿Qué laptops pueden ser nodos (RAM, Ethernet, Linux) y estar disponibles el día de la sustentación? | Inventariar en el hito de diseño. Junto con Q-01, define el perfil |

## 14. Organización del trabajo

**Organización GitHub:** `kitsalud-movil-plats1`

| Repositorio | Contenido |
|---|---|
| `.github` | Perfil de la organización y plantillas de issues y PR |
| `docs` | Arquitectura, decisiones, diagramas, guías E2-E6 y sustentación |
| `network` | Configuración exportada de OPNsense (sin secretos), switch y AP |
| `platform` | Nodos KVM (libvirt, netplan), infra01 (BIND9, Chrony, Samba AD), ops01 (Samba, NFS), backups (restic, rest-server), Ansible |
| `apps` | Compose de DHIS2 (apps01) y de web01 (Caddy, Kiwix, formularios) |
| `observability` | Prometheus, reglas de alerta, dashboards de Grafana, configuración de rsyslog |

**Flujo de trabajo:**

- `main` protegida; ramas `feat/<tema>` o `fix/<tema>`.
- PR con al menos una revisión y referencia al issue y al ID de decisión o requisito (p. ej. `R2`, `D-12`).
- Commits en español e imperativo.
- Nunca se suben secretos: `.gitignore` los excluye; `.env.example` sirve de plantilla.

## 15. Próximos pasos por hito

| Hito | Tareas iniciales |
|---|---|
| Diseño | Revisar este documento en grupo, resolver Q-01 a Q-07, confirmar hardware y elegir el perfil (10.3), prueba de humo de DHIS2 (R-03), probar VLAN en los adaptadores USB (R-08), crear el tablero Kanban |
| Servicios base | Instalar kvm01 (y los nodos adicionales) con sus bridges; fw01 con VLAN, DHCP y RA; infra01 (DNS, NTP y AD); acceso administrativo |
| Almacenamiento y aplicaciones | ops01 (SMB/NFS), DHIS2, web01 (Kiwix y app de formularios), TLS interno |
| Wi-Fi y seguridad | AP y SSID, portal cautivo, matriz de flujos v4/v6 definitiva (E4), firewall local en los servidores de la VLAN 20 |
| Resiliencia | restic con rest-server y restauración, apagado ordenado con NUT simulado, autostart, observabilidad (Prometheus, Grafana, rsyslog), prueba sin Internet |
| Entrega final | Guías E2/E3, evidencias P1-P13, limpieza del repositorio, sustentación |

## 16. Historial de cambios

| Versión | Fecha | Cambios |
|---|---|---|
| v0.1 | 2026-09-24 | Documento inicial |
| v0.2 | 2026-09-27 | Simplificación del diseño. Se elimina la DMZ (VLAN 50): biblioteca y formularios pasan a web01 en la VLAN 20 (D-15, R-06). Se quitan el SSID de gestión (D-18), Alertmanager y SNMP (D-09), el login LDAP en DHIS2 (D-06), apt-cacher-ng (R-05) y la copia externa con rclone (D-10). Se fijan Caddy `tls internal` con una sola raíz (D-16) y `ansible-vault` (D-17). Se cierra Q-04. Se agrega el diagrama físico (5.4) y se corrige el total de memoria (sección 12) |
| v0.3 | 2026-09-28 | Ajuste al hardware disponible. Los recursos se fijan por VM (10.1) y se agregan perfiles de despliegue: solo mini PC, mini PC + laptops o solo laptops (10.2-10.4, S-01, S-11, D-01, 5.2). De siete a cinco VMs con una IP por rol: infra01 aloja dc01 y ops01 aloja files01 y mon01 (D-19). Redimensionamiento: de 28 GB y 552 GB (+ 1 TB de backups) a 12,5 GB y ≈ 200 GB (+ disco USB). Logs con rsyslog en lugar de Loki/Alloy (D-09). Backups con restic hacia un rest-server append-only en un disco USB (D-10, F-20). Energía por perfil (12), crecimiento (12.1), riesgos R-07 a R-09 y Q-07 |
