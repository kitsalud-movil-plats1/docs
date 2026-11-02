# P5 - Portal cautivo

**Fecha.** 2026-11-02, 16:45 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird · **Versión.** `docs` `ddb5f1f`, `network` `1133967`, `platform` `025b11c`, `apps` `3969c3b`, `observability` `43b7ed6`

## Qué se prueba

Un cliente nuevo es redirigido al portal cautivo.

**Cómo se probó.** Primero se quitó la autorización de `prueba01` en kit01 (`./scripts/en-prueba01.sh --sin-portal`), para que fuera un cliente nuevo. `prueba01` es una máquina virtual de kit01 conectada a la red Comunidad, con su configuración recibida por DHCP. Después ejecutó `./scripts/en-prueba01.sh P05-portal.sh --aceptar`, que revisa a dónde va su tráfico web antes de aceptar, envía lo mismo que el botón Acepto y revisa a dónde va después. En kit01 se revisaron la lista de equipos autorizados y el registro del portal.

## Comandos y salida

```
== P05 - Portal cautivo
Fecha 2026-11-02 16:45:54 -0500 · equipo prueba01 · Linux

## Antes de aceptar
  [ OK ]  IPv4 http://neverssl.com va al portal (302 http://portal.salud.movil/)
  [ OK ]  IPv6 http://biblioteca.salud.movil va al portal
  [ OK ]  El HTTPS sin aceptar se rechaza
  [ OK ]  http://portal.salud.movil/ muestra las condiciones con el botón Acepto

## Aceptar
  [ OK ]  POST /aceptar (lo mismo que tocar Acepto) (303)
  [ OK ]  IPv4 http://biblioteca.salud.movil después de aceptar (200)
  [ OK ]  IPv6 http://biblioteca.salud.movil después de aceptar (200)
  [ OK ]  http://portal.salud.movil/ ahora muestra el menú
          En kit01: sudo nft list set inet filtro portal_ok y grep -v Blackbox /var/log/nginx/portal.log | tail

Resultado: 8 bien y 0 con falla.
```

**En kit01.**

```
$ sudo nft list set inet filtro portal_ok | grep elements
		elements = { 52:54:00:40:00:50 expires 7h29m51s95ms }

$ grep -v Blackbox /var/log/nginx/portal.log | grep '16:4[5-7]'
fd5a:fc7e:d716:40:5054:ff:fe40:50 - - [02/Nov/2026:16:45:54 -0500] "GET / HTTP/1.1" 302 138 "-" "curl/8.5.0"
fd5a:fc7e:d716:40:5054:ff:fe40:50 - - [02/Nov/2026:16:45:54 -0500] "GET / HTTP/1.1" 200 704 "-" "curl/8.5.0"
10.20.40.114 - - [02/Nov/2026:16:45:54 -0500] "POST /aceptar HTTP/1.1" 303 16 "-" "curl/8.5.0"
fd5a:fc7e:d716:40:5054:ff:fe40:50 - - [02/Nov/2026:16:45:55 -0500] "GET / HTTP/1.1" 200 865 "-" "curl/8.5.0"
```

La lista se revisó media hora después de aceptar, por eso le quedan 7 h 29 min de las 8 h que dura la autorización.

### IPv4

Antes de aceptar, una página externa por HTTP (`http://neverssl.com`) devolvió una redirección a `http://portal.salud.movil/`, el HTTPS se rechazó enseguida y el portal mostró las condiciones con el botón Acepto. La aceptación respondió 303 y desde ese momento la biblioteca respondió 200 por IPv4.

### IPv6

Antes de aceptar, la biblioteca pedida por IPv6 también fue al portal, y el registro de kit01 muestra esa visita desde la dirección IPv6 del cliente. Después de aceptar, la biblioteca respondió 200 por IPv6, porque la autorización queda guardada por la MAC del equipo y vale para las dos familias.

## Interpretación

Un cliente nuevo no llega a nada sin pasar por el portal, sin importar la página que pida ni la familia que use. Al aceptar, kit01 agrega su MAC a la lista de equipos autorizados por 8 horas y el cliente pasa a usar los servicios públicos. El portal está en kit01, así que funciona también sin Internet.

## Resultado

Aprobada. 8 comprobaciones bien y ninguna falla. En la sustentación se repite con un celular en el SSID de la Comunidad. Con Internet, el teléfono abre el portal solo al conectarse.
