# P10 - Firewall IPv6

**Fecha.** 2026-11-02, 16:57 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird · **Versión.** `docs` `ddb5f1f`, `network` `1133967`, `platform` `025b11c`, `apps` `3969c3b`, `observability` `43b7ed6`

## Qué se prueba

Se realizan una prueba de acceso permitido y otra de acceso bloqueado mediante IPv6.

**Cómo se probó.** `prueba01`, la máquina virtual de kit01 conectada a la red Comunidad, con su dirección IPv6 formada por SLAAC y el portal aceptado, ejecutó `./scripts/en-prueba01.sh P10-firewall-ipv6.sh`. Primero por IPv6 y después por IPv4, para comparar, abre la biblioteca y el formulario de `comunidad01` (permitidos) e intenta abrir la historia clínica y el servidor web de `clinica01` y el SSH de kit01 (bloqueados). En kit01 se revisó el registro del firewall.

## Comandos y salida

```
== P10 - Firewall IPv6
Fecha 2026-11-02 16:57:48 -0500 · equipo prueba01 · Linux

## IPv6
  [ OK ]  IPv6 permitido: http://biblioteca.salud.movil/ (200)
  [ OK ]  IPv6 permitido: https://registro.salud.movil/ (200)
  [ OK ]  IPv6 bloqueado: https://pacientes.salud.movil/
  [ OK ]  IPv6 bloqueado: http://[fd5a:fc7e:d716:20::11]/
  [ OK ]  IPv6 bloqueado: SSH de kit01

## IPv4
  [ OK ]  IPv4 permitido: http://biblioteca.salud.movil/ (200)
  [ OK ]  IPv4 permitido: https://registro.salud.movil/ (200)
  [ OK ]  IPv4 bloqueado: https://pacientes.salud.movil/
  [ OK ]  IPv4 bloqueado: http://10.20.20.11/
  [ OK ]  IPv4 bloqueado: SSH de kit01
          Origen IPv6: fd5a:fc7e:d716:40:5054:ff:fe40:50
          En kit01: grep SRC=fd5a:fc7e:d716:0040 /var/log/kitsalud/kit01/firewall.log | tail (prefijo fw-drop)

Resultado: 10 bien y 0 con falla.
```

**Registro del firewall en kit01** (sin la MAC, el largo ni otros campos de la cabecera).

```
2026-11-02T16:57:48-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=br-srv SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0020:0000:0000:0000:0011 PROTO=TCP SPT=46332 DPT=443 SYN
2026-11-02T16:57:53-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT=br-srv SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0020:0000:0000:0000:0011 PROTO=TCP SPT=44936 DPT=80 SYN
2026-11-02T16:57:58-05:00 kit01 kernel: fw-drop F-20 IN=br-com OUT= SRC=fd5a:fc7e:d716:0040:5054:00ff:fe40:0050 DST=fd5a:fc7e:d716:0020:0000:0000:0000:0010 PROTO=TCP SPT=39162 DPT=22 SYN
```

La etiqueta `fw-drop F-20` es la que el firewall de kit01 pone a lo que descarta de la red Comunidad hacia `clinica01` y hacia la administración de kit01.

### IPv6

Desde `fd5a:fc7e:d716:40:5054:ff:fe40:50`, la biblioteca respondió 200 y el formulario de registro respondió 200 por HTTPS. La historia clínica, el servidor web de `fd5a:fc7e:d716:20::11` y el SSH de kit01 no abrieron, y los tres intentos quedaron en el registro con la dirección IPv6 de origen.

### IPv4

Las mismas cinco pruebas por IPv4 dieron el mismo resultado.

## Interpretación

El firewall aplica la misma política en IPv6 que en IPv4. Cada equipo del kit tiene también su dirección IPv6 y kit01 enruta entre las redes en las dos familias, así que un firewall que solo filtrara IPv4 dejaría llegar a un invitado a `clinica01` por IPv6. Las reglas de kit01 están escritas para las dos familias y la prueba lo confirma, con lo permitido abierto, lo clínico y la administración cerrados y los intentos registrados.

## Resultado

Aprobada. 10 comprobaciones bien y ninguna falla. En la sustentación se repite con un celular que tenga IPv6 en el SSID de la Comunidad.
