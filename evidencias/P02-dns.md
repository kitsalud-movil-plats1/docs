# P2 - DNS

**Entorno.** Kit real, en remoto por NetBird

## Qué se prueba

Se resuelve por nombre un servicio con registros A y AAAA y se accede sin escribir la IP. Se demuestra además la conectividad extremo a extremo con ping, resolución DNS y acceso por IPv6.

**Cómo se probó.** Desde dos redes. En la red Comunidad, `prueba01` (una máquina virtual de kit01 conectada a esa red, que recibe su configuración por DHCP como un celular) ejecutó `P02-dns.sh`. Revisa los registros A y AAAA de todos los servicios, la respuesta autoritativa del DNS del kit por IPv4 y por IPv6, la delegación del dominio del directorio, las zonas inversas y el acceso HTTP por nombre. El ping a los servidores solo se permite desde la red Interna, así que esa parte se hizo desde sw01, el switch del kit, que tiene su gestión en la red Interna (`P02-dns.sh --sw01`). sw01 no tiene servidor DNS propio y RouterOS 7.13 solo pide registros A, así que se le indica el DNS del kit en cada consulta y la dirección IPv6 de la biblioteca la da el DNS del kit.

## Comandos y salida

**Desde la red Comunidad** (`./scripts/en-prueba01.sh P02-dns.sh`).

```
== P02 - DNS

## Registros A y AAAA
  [ OK ]  A    biblioteca.salud.movil (10.20.20.12)
  [ OK ]  AAAA biblioteca.salud.movil (fd5a:fc7e:d716:20::12)
  [ OK ]  A    videos.salud.movil (10.20.20.12)
  [ OK ]  AAAA videos.salud.movil (fd5a:fc7e:d716:20::12)
  [ OK ]  A    registro.salud.movil (10.20.20.12)
  [ OK ]  AAAA registro.salud.movil (fd5a:fc7e:d716:20::12)
  [ OK ]  A    ca.salud.movil (10.20.20.12)
  [ OK ]  AAAA ca.salud.movil (fd5a:fc7e:d716:20::12)
  [ OK ]  A    pacientes.salud.movil (10.20.20.11)
  [ OK ]  AAAA pacientes.salud.movil (fd5a:fc7e:d716:20::11)
  [ OK ]  A    consultas.salud.movil (10.20.20.11)
  [ OK ]  AAAA consultas.salud.movil (fd5a:fc7e:d716:20::11)
  [ OK ]  A    archivos.salud.movil (10.20.20.11)
  [ OK ]  AAAA archivos.salud.movil (fd5a:fc7e:d716:20::11)
  [ OK ]  A    ntp.salud.movil (10.20.20.10)
  [ OK ]  AAAA ntp.salud.movil (fd5a:fc7e:d716:20::10)
  [ OK ]  A    monitoreo.salud.movil (10.20.20.10)
  [ OK ]  AAAA monitoreo.salud.movil (fd5a:fc7e:d716:20::10)
  [ OK ]  A    portal.salud.movil (10.20.40.1)
  [ OK ]  AAAA portal.salud.movil (fd5a:fc7e:d716:40::1)

## Servidor del kit, delegación AD e inversas (dig)
  [ OK ]  Respuesta autoritativa del DNS del kit por IPv4 (bandera aa)
  [ OK ]  Consulta al DNS del kit por IPv6 (fd5a:fc7e:d716:20::11)
  [ OK ]  Delegación a Samba AD (_ldap._tcp.ad.salud.movil → dc01)
  [ OK ]  Inversa IPv4 de 10.20.20.12 (comunidad01.salud.movil.)
  [ OK ]  Inversa IPv6 de fd5a:fc7e:d716:20::12 (comunidad01.salud.movil.)

## Extremo a extremo por nombre
          El ping a las VMs solo se permite desde la Interna; se omite (P02-dns.sh --sw01 lo hace desde sw01)
  [ OK ]  HTTP IPv4 a http://biblioteca.salud.movil (200)
  [ OK ]  HTTP IPv6 a http://biblioteca.salud.movil (200)

Resultado: 27 bien y 0 con falla.
```

**Desde la red Interna** (`./scripts/P02-dns.sh --sw01`).

```
== P02 - DNS
          Desde sw01 (10.20.10.2, red Interna), por el salto de kit01

## Consultas al DNS del kit desde sw01
  [ OK ]  A biblioteca.salud.movil preguntando a 10.20.20.10 (10.20.20.12)
  [ OK ]  A pacientes.salud.movil preguntando a 10.20.20.10 (10.20.20.11)
  [ OK ]  A archivos.salud.movil preguntando a 10.20.20.10 (10.20.20.11)
  [ OK ]  A monitoreo.salud.movil preguntando a 10.20.20.10 (10.20.20.10)
  [ OK ]  A biblioteca.salud.movil preguntando a fd5a:fc7e:d716:20::10 (10.20.20.12)
  [ OK ]  A pacientes.salud.movil preguntando a fd5a:fc7e:d716:20::10 (10.20.20.11)
  [ OK ]  A archivos.salud.movil preguntando a fd5a:fc7e:d716:20::10 (10.20.20.11)
  [ OK ]  A monitoreo.salud.movil preguntando a fd5a:fc7e:d716:20::10 (10.20.20.10)

## Por nombre desde sw01
          biblioteca.salud.movil es 10.20.20.12 y fd5a:fc7e:d716:20::12 (el AAAA lo da el DNS del kit)
  [ OK ]  ping IPv4 a biblioteca.salud.movil (10.20.20.12), respuestas (3)
  [ OK ]  ping IPv6 a biblioteca.salud.movil (fd5a:fc7e:d716:20::12), respuestas (3)
  [ OK ]  HTTP IPv4 a http://biblioteca.salud.movil (status: finished)
  [ OK ]  HTTP IPv6 a http://biblioteca.salud.movil (status: finished)

Resultado: 12 bien y 0 con falla.
```

### IPv4

Los diez nombres del kit tienen su registro A y el DNS del kit responde como autoritativo para `salud.movil`. Desde la Interna, sw01 obtuvo los registros A preguntando al DNS por su dirección IPv4, hizo ping a `biblioteca.salud.movil` (3 respuestas de 3) y descargó la página por HTTP. Desde la Comunidad la biblioteca respondió por nombre con código 200.

### IPv6

Los diez nombres tienen su registro AAAA, el DNS del kit responde consultas por su dirección `fd5a:fc7e:d716:20::10` y la inversa de `fd5a:fc7e:d716:20::12` devuelve `comunidad01.salud.movil`. sw01 también consultó el DNS por IPv6, hizo ping a la dirección IPv6 de la biblioteca y descargó la página por IPv6. Desde la Comunidad la biblioteca respondió por nombre en IPv6 con código 200.

## Interpretación

Todos los servicios del kit se encuentran por nombre en las dos familias, con el mismo nombre para IPv4 e IPv6, así que nadie necesita escribir direcciones. El DNS del kit es autoritativo para `salud.movil`, delega `ad.salud.movil` al controlador del directorio en `clinica01` y responde las inversas, lo que permite ver nombres en los registros. La conectividad extremo a extremo funciona desde la red Interna con ping, DNS y HTTP en IPv4 e IPv6, y desde la Comunidad el acceso web por nombre funciona en las dos familias.

## Resultado

Aprobada. 39 comprobaciones bien y ninguna falla (27 desde la Comunidad y 12 desde la Interna). En la sustentación se repite desde un PC de la red Interna, que hace el ping por nombre directamente.
