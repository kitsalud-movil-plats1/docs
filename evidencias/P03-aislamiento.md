# P3 - Aislamiento

**Entorno.** Kit real, en remoto por NetBird

## Qué se prueba

Un cliente de invitados intenta acceder a un servicio clínico o de administración y la conexión queda bloqueada.

**Cómo se probó.** El cliente de invitados es `prueba01`, una máquina virtual de kit01 conectada a la red Comunidad (la red del SSID abierto), con su configuración recibida por DHCP y el portal ya aceptado, como un celular que ya entró. Con `./scripts/en-prueba01.sh P03-aislamiento.sh` intentó llegar en IPv4 y en IPv6 a la historia clínica (DHIS2), a la consulta de prerregistros, a los archivos compartidos, a la consola de monitoreo, al SSH de kit01, a la red Interna y a la gestión del punto de acceso y del switch. En kit01 se revisó después el registro del firewall.

## Comandos y salida

```
== P03 - Aislamiento

## IPv4
  [ OK ]  IPv4 bloqueado: DHIS2 (clinica01 443)
  [ OK ]  IPv4 bloqueado: consulta de prerregistros (clinica01 443)
  [ OK ]  IPv4 bloqueado: SMB de clinica01 (archivos.salud.movil puerto 445)
  [ OK ]  IPv4 bloqueado: Grafana (kit01 443)
  [ OK ]  IPv4 bloqueado: SSH de kit01 (ns1.salud.movil puerto 22)
  [ OK ]  IPv4 bloqueado: SSH de kit01 por su IP de la Comunidad (portal.salud.movil puerto 22)

## IPv6
  [ OK ]  IPv6 bloqueado: DHIS2 (clinica01 443)
  [ OK ]  IPv6 bloqueado: consulta de prerregistros (clinica01 443)
  [ OK ]  IPv6 bloqueado: SMB de clinica01 (archivos.salud.movil puerto 445)
  [ OK ]  IPv6 bloqueado: Grafana (kit01 443)
  [ OK ]  IPv6 bloqueado: SSH de kit01 (ns1.salud.movil puerto 22)
  [ OK ]  IPv6 bloqueado: SSH de kit01 por su IP de la Comunidad (portal.salud.movil puerto 22)

## Interna y gestión de los equipos de red
  [ OK ]  IPv4 la Interna (10.20.10.1) no responde
  [ OK ]  IPv4 bloqueado: gestión del AP (http://10.20.10.3)
  [ OK ]  IPv4 bloqueado: SSH del switch (10.20.10.2 puerto 22)
  [ OK ]  IPv6 la Interna (fd5a:fc7e:d716:10::1) no responde
  [ OK ]  IPv6 bloqueado: SSH del switch (fd5a:fc7e:d716:10::2 puerto 22)
          En kit01 los intentos quedan en /var/log/kitsalud/kit01/firewall.log con el prefijo fw-drop
          Origen de esta prueba: 10.20.40.114 fd5a:fc7e:d716:40:5054:ff:fe40:50

Resultado: 17 bien y 0 con falla.
```

**Registro del firewall en kit01** (`/var/log/kitsalud/kit01/firewall.log`, un intento de cada destino, sin la MAC, el largo, la ventana ni otros campos de la cabecera).

```
2026-11-02T16:51:20-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=br-srv SRC=10.20.40.114 DST=10.20.20.11 PROTO=TCP SPT=59546 DPT=443 SYN
2026-11-02T16:51:27-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=br-srv SRC=10.20.40.114 DST=10.20.20.11 PROTO=TCP SPT=45954 DPT=445 SYN
2026-11-02T16:51:32-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT= SRC=10.20.40.114 DST=10.20.20.10 PROTO=TCP SPT=54406 DPT=443 SYN
2026-11-02T16:51:37-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT= SRC=10.20.40.114 DST=10.20.20.10 PROTO=TCP SPT=40330 DPT=22 SYN
2026-11-02T16:51:42-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT= SRC=10.20.40.114 DST=10.20.40.1 PROTO=TCP SPT=41596 DPT=22 SYN
2026-11-02T16:51:47-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=br-srv SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0020:0000:0000:0000:0011 PROTO=TCP SPT=40514 DPT=443 SYN
2026-11-02T16:51:57-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=br-srv SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0020:0000:0000:0000:0011 PROTO=TCP SPT=34760 DPT=445 SYN
2026-11-02T16:52:02-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT= SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0020:0000:0000:0000:0010 PROTO=TCP SPT=44198 DPT=443 SYN
2026-11-02T16:52:07-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT= SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0020:0000:0000:0000:0010 PROTO=TCP SPT=44908 DPT=22 SYN
2026-11-02T16:52:12-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT= SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0040:0000:0000:0000:0001 PROTO=TCP SPT=36140 DPT=22 SYN
2026-11-02T16:52:17-05:00 kit01 kernel: fw-drop IN=br-com OUT= SRC=10.20.40.114 DST=10.20.10.1 PROTO=ICMP TYPE=8 CODE=0
2026-11-02T16:52:21-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=lan0.10 SRC=10.20.40.114 DST=10.20.10.3 PROTO=TCP SPT=42328 DPT=80 SYN
2026-11-02T16:52:26-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=lan0.10 SRC=10.20.40.114 DST=10.20.10.2 PROTO=TCP SPT=46294 DPT=22 SYN
2026-11-02T16:52:35-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=lan0.10 SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0010:0000:0000:0000:0002 PROTO=TCP SPT=42008 DPT=22 SYN
```

La etiqueta `fw-drop F-20` es la que el firewall de kit01 pone a lo que descarta de la red Comunidad hacia la red Interna, hacia `clinica01` y hacia la administración de kit01. El ping a `10.20.10.1` lleva la etiqueta general `fw-drop` porque va dirigido a kit01 y lo descarta la regla final de entrada.

### IPv4

Desde `10.20.40.114`, las conexiones a DHIS2 y a la consulta (443 de `10.20.20.11`), a los archivos (445), a la consola de monitoreo (443 de `10.20.20.10`), al SSH de kit01 por sus dos direcciones, a la gestión del punto de acceso (`10.20.10.3`) y al SSH del switch (`10.20.10.2`) no se abrieron, y el ping a la red Interna no tuvo respuesta. Cada intento aparece en el registro de kit01.

### IPv6

Desde `fd5a:fc7e:d716:40:5054:ff:fe40:50`, las mismas conexiones hacia `fd5a:fc7e:d716:20::11`, `fd5a:fc7e:d716:20::10`, `fd5a:fc7e:d716:40::1` y el SSH del switch en `fd5a:fc7e:d716:10::2` quedaron bloqueadas, y el ping a `fd5a:fc7e:d716:10::1` no tuvo respuesta. El firewall las registra igual que en IPv4. El punto de acceso solo tiene gestión por IPv4.

## Interpretación

Un invitado que ya aceptó el portal no llega a nada clínico ni administrativo, en ninguna de las dos familias. El bloqueo está en kit01, que es el router entre las redes, así que no depende de que los servicios tengan contraseña. Cada intento queda registrado con su origen y su destino, lo que permite ver en el registro central quién intentó llegar a dónde.

## Resultado

Aprobada. 17 comprobaciones bien y ninguna falla, con los intentos registrados. En la sustentación se muestra además con dos celulares en el SSID de la Comunidad que un cliente no ve al otro, porque el punto de acceso aísla a sus clientes.
