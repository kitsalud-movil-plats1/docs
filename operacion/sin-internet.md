# Operación sin Internet

El kit está hecho para trabajar sin Internet. Todos los servicios que usa la brigada corren dentro del kit, así que un sitio sin conexión, o una conexión que se cae a mitad de la jornada, no detiene la atención. Este procedimiento explica qué cambia sin Internet, cómo administrar el kit en ese caso y qué revisar cuando la conexión vuelve.

## Qué sigue funcionando y qué no

| Sigue funcionando | Deja de funcionar |
|---|---|
| Direcciones para los equipos (DHCP en IPv4 y anuncios de IPv6) | Navegar por Internet desde la Interna y la Comunidad |
| Los nombres de `salud.movil` y del dominio en el DNS del kit | Los nombres de Internet. A la Comunidad el DNS le responde la IP del portal y a la Interna `SERVFAIL` |
| La hora, que kit01 sigue entregando a todos los equipos | La sincronización de kit01 con servidores de hora externos |
| Historia clínica (DHIS2), consulta de prerregistros y archivos compartidos | La administración remota por NetBird |
| Biblioteca, videos y formulario de prerregistro | Actualizaciones de paquetes y de imágenes de las aplicaciones |
| Portal cautivo de la Comunidad, que el celular abre solo | Las páginas externas con `https://` |
| Inicio de sesión con las cuentas del dominio y de DHIS2 | |
| Monitoreo (Grafana), logs centralizados y copias de respaldo | |

**Hora.** kit01 conserva la última referencia que tenía. Si el corte se alarga, pasa a estrato 10 y sigue sirviendo la hora a los equipos, que se mantienen sincronizados entre sí. La hora del kit se puede alejar poco a poco de la hora real. Todos los equipos siguen con la misma hora, que es lo que necesitan el dominio y los registros clínicos.

**Portal cautivo.** Menos de un minuto después de que se corta Internet, kit01 pasa a modo sin Internet y el DNS responde a la Comunidad cualquier nombre externo con la dirección del portal. Así el celular abre el portal solo, y cualquier dirección que se escriba por HTTP termina en él, con las condiciones o con el menú si ya aceptó. Las direcciones con `https://` no muestran el portal. Cuando vuelve Internet, en menos de un minuto todo resuelve normalmente.

## Cómo saber si el kit tiene Internet

Se revisa en kit01.

```bash
ip route show default                       # default via <gateway del sitio> dev enp170s0
ping -c 3 1.1.1.1                           # 0% packet loss con Internet
dig +short @10.20.20.10 example.org         # direcciones con Internet; vacío o SERVFAIL sin Internet
cat /run/kit-internet/modo                  # con o sin
chronyc tracking | grep -E "Stratum|Leap"   # Leap status Normal en los dos casos
```

| Comando | Con Internet | Sin Internet |
|---|---|---|
| `ip route show default` | Una ruta por `enp170s0` | Puede seguir apareciendo, así que la prueba que vale es el `ping` |
| `ping -c 3 1.1.1.1` | `0% packet loss` | `100% packet loss` o `Network is unreachable` |
| `dig @10.20.20.10 example.org` | Direcciones IPv4 | `SERVFAIL` o sin respuesta |
| `dig +short @10.20.20.10 pacientes.salud.movil` | `10.20.20.11` | `10.20.20.11` |
| `cat /run/kit-internet/modo` | `con` | `sin`, menos de un minuto después del corte. `journalctl -t kit-internet` muestra cada cambio |
| `chronyc tracking` | Estrato 2 o 3 | El último estrato que tenía, y 10 si el corte se alarga |

El tablero de monitoreo no se pone en rojo por falta de Internet, porque todo lo que vigila está dentro del kit. Si el cable de la WAN está conectado y aun así no hay Internet, se revisa que el enlace esté arriba (`ip link show enp170s0` tiene que decir `UP`) y que la dirección de la WAN corresponda a la red del sitio (`ip addr show enp170s0`).

## Administrar el kit sin NetBird

Sin Internet no hay acceso remoto, así que el kit se administra desde un equipo conectado a la red Interna, por cable a un puerto de la Interna del switch o por el Wi-Fi `SaludMovil-Clinica`. kit01 acepta SSH y el monitoreo solo desde las direcciones de administración, de `10.20.10.10` a `10.20.10.29`.

Hay dos formas de tener una de esas direcciones.

- **Reserva por MAC.** La forma permanente. Se agrega el equipo al inventario de Ansible, en `platform/ansible/inventarios/kit/group_vars/all/dhcp.yml`, y se aplica con `ansible-playbook playbooks/dhcp.yml`. Desde ahí el equipo recibe siempre la misma dirección.

  ```yaml
  dhcp_reservas:
    - { nombre: laptop-ana, mac: "aa:bb:cc:dd:ee:ff", ipv4: 10.20.10.10 }
  ```

- **Dirección fija a mano.** Para un equipo sin reserva. Se configura en el equipo la dirección `10.20.10.29/24`, la puerta de enlace `10.20.10.1` y el DNS `10.20.20.10`. Las direcciones de `10.20.10.10` a `10.20.10.29` están fuera del rango que entrega el DHCP, así que no chocan con otros equipos. Al terminar se vuelve el equipo a DHCP.

Con la dirección de administración, el acceso es el mismo que por NetBird, cambiando la dirección de kit01.

```bash
ssh <usuario>@10.20.10.1                              # kit01
ssh -J <usuario>@10.20.10.1 <usuario>@10.20.20.11     # clinica01
ssh -J <usuario>@10.20.10.1 <usuario>@10.20.20.12     # comunidad01
```

El monitoreo está en `https://monitoreo.salud.movil`. El SSH desde la Interna funciona solo por IPv4, porque las direcciones de administración son IPv4.

## Cuando vuelve Internet

No hay que hacer nada para que el kit vuelva a salir. La ruta por la WAN, la hora y NetBird se recuperan solos.

```bash
chronyc tracking | grep -E "Reference|Stratum"    # vuelve a una referencia externa, estrato 2 o 3
sudo netbird status | grep -E "Management|Signal" # Connected en los dos
```

La hora puede tardar unos minutos en volver a una referencia externa, y si kit01 se había alejado de la hora real la corrige de a poco, sin saltos. Las actualizaciones no se hacen en campo aunque vuelva Internet. Se hacen en la base, en una ventana de mantenimiento.

## Prueba hecha en el kit

En el kit se cortó la salida a Internet de kit01 durante 5 minutos con una tabla temporal del firewall, sin desconectar el cable para no perder el acceso remoto. Con el corte se comprobaron 40 cosas en IPv4 y en IPv6, desde kit01, las dos máquinas virtuales, el switch (red Interna) y una máquina de prueba en la red Comunidad.

- Los nombres de Internet dieron `SERVFAIL` y las máquinas virtuales y la Comunidad no llegaron a Internet.
- El DNS del kit respondió todos sus nombres, y kit01 siguió sincronizado (estrato 3) y entregando la hora.
- DHIS2, la consulta de prerregistros y los archivos compartidos respondieron.
- La máquina de la Comunidad vio el portal, lo aceptó, usó la biblioteca, los videos y el formulario, y su prerregistro quedó guardado.
- El monitoreo no puso nada en rojo y ninguna unidad falló en kit01.
- Al quitar la tabla, la salida a Internet volvió sola.

Se revisaron en kit01, con Internet, los comandos de este procedimiento. Dieron la ruta por `enp170s0`, `0% packet loss`, direcciones para `example.org`, `10.20.20.11` para `pacientes.salud.movil`, estrato 3 con `Leap status Normal` y NetBird conectado.
