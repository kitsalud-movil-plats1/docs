# P9 - Pérdida de Internet

**Fecha.** 2026-11-02, de 15:12 a 15:17 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird, con el corte de Internet simulado · **Versión.** `docs` `92cd7a7`, `network` `1133967`, `platform` `025b11c`, `apps` `3969c3b`

## Qué se prueba

Se desconecta la salida externa y los servicios locales esenciales continúan disponibles. Todo lo esencial vive en el kit, como el DNS de `salud.movil`, la hora, el DHCP, el portal, la historia clínica (DHIS2), los archivos compartidos, la biblioteca, los videos y el formulario de prerregistro.

**Cómo se cortó Internet.** Desconectar el cable de la WAN corta también el acceso remoto, así que se usó una tabla de nftables temporal en kit01, con borrado automático a los 15 minutos. La tabla descarta todo lo que el kit reenvía hacia la WAN, así que las VMs y los clientes de las redes Interna y Comunidad se quedan sin Internet. En kit01 descarta el DNS hacia afuera (reenviadores y servidores raíz), el NTP y el HTTP de los repositorios de paquetes. Solo deja pasar lo que necesita el túnel de administración (su UDP, su HTTPS y el DNS del sitio). Para los servicios del kit el efecto es el mismo que desconectar el cable.

```
table inet prueba_sin_internet {
	chain forward {
		type filter hook forward priority filter - 10; policy accept;
		oifname "enp170s0" counter drop
	}
	chain output {
		type filter hook output priority filter - 10; policy accept;
		oifname "enp170s0" meta l4proto { tcp, udp } th dport 53 ip daddr != { 192.168.215.20, 192.168.215.30 } counter drop
		oifname "enp170s0" udp dport 123 counter drop
		oifname "enp170s0" tcp dport 80 counter drop
	}
}
```

## Comandos y salida

Se ejecutó `./scripts/P09-sin-internet-remoto.sh` en la máquina de control. Prueba desde kit01, desde las dos VMs, desde el switch (red Interna) y desde una VM conectada a la red Comunidad (`prueba01`), que hace de celular.

```
## 1. Antes del corte
  [ OK ]  Sondas en rojo (0)
  [ OK ]  clinica01 llega a Internet (https://www.google.com) (200)
  [ OK ]  prueba01 encendida (Comunidad)
  [ OK ]  prueba01 sin el portal aceptado

## 2. Corte de Internet
    corte aplicado a las 15:13:53
  [ OK ]  Tabla del corte activa (table inet prueba_sin_internet)
  [ OK ]  NetBird sigue: esta máquina de control sigue entrando a kit01
          Se borra sola a los 15 min (fin-prueba_sin_internet.timer). Esperando 60 s

## 3. Lo externo falla
  [ OK ]  clinica01 hacia https://www.google.com (sin conexión)
  [ OK ]  prueba01 hacia https://www.google.com (sin conexión)
  [ OK ]  Un nombre externo no resuelve (status: SERVFAIL)
    Contadores del corte:
      oifname "enp170s0" counter packets 28
      oifname "enp170s0" meta l4proto { tcp, udp } th dport 53 ip daddr != { 192.168.215.20, 192.168.215.30 } counter packets 15
      oifname "enp170s0" udp dport 123 counter packets 1
      oifname "enp170s0" tcp dport 80 counter packets 0

## 4. DNS y hora del kit
  [ OK ]  pacientes.salud.movil A y AAAA (10.20.20.11 fd5a:fc7e:d716:20::11)
  [ OK ]  consultas.salud.movil A y AAAA (10.20.20.11 fd5a:fc7e:d716:20::11)
  [ OK ]  biblioteca.salud.movil A y AAAA (10.20.20.12 fd5a:fc7e:d716:20::12)
  [ OK ]  videos.salud.movil A y AAAA (10.20.20.12 fd5a:fc7e:d716:20::12)
  [ OK ]  registro.salud.movil A y AAAA (10.20.20.12 fd5a:fc7e:d716:20::12)
  [ OK ]  portal.salud.movil A y AAAA (10.20.40.1 fd5a:fc7e:d716:40::1)
  [ OK ]  archivos.salud.movil A y AAAA (10.20.20.11 fd5a:fc7e:d716:20::11)
    kit01 Stratum         : 3
    kit01 Leap status     : Normal
  [ OK ]  clinica01 toma la hora de kit01 (^*)

## 5. Servicios de la Clínica y red Interna
  [ OK ]  DHIS2 por 10.20.20.11 (200)
  [ OK ]  Consulta de prerregistros por 10.20.20.11 (200)
  [ OK ]  DHIS2 por [fd5a:fc7e:d716:20::11] (200)
  [ OK ]  Consulta de prerregistros por [fd5a:fc7e:d716:20::11] (200)
  [ OK ]  sw01 (Interna) llega a la biblioteca por 10.20.20.12 (status: finished)
  [ OK ]  sw01 (Interna) llega a la biblioteca por [fd5a:fc7e:d716:20::12] (status: finished)
  [ OK ]  Recurso archivos por SMB con ana.rojas (abre)

## 6. Comunidad (prueba01)
  [ OK ]  IPv4 biblioteca sin aceptar el portal (redirige) (302)
  [ OK ]  IPv6 biblioteca sin aceptar el portal (redirige) (302)
  [ OK ]  Portal aceptado sin Internet
  [ OK ]  IPv4 biblioteca (200)
  [ OK ]  IPv4 videos (302)
  [ OK ]  IPv4 registro (HTTPS con la raíz del kit) (200)
  [ OK ]  IPv6 biblioteca (200)
  [ OK ]  IPv6 videos (302)
  [ OK ]  IPv6 registro (HTTPS con la raíz del kit) (200)
  [ OK ]  Prerregistro enviado sin Internet y guardado en clinica01 (código UFJT)

## 7. Estado general durante el corte
  [ OK ]  Sondas en rojo (0)
  [ OK ]  Unidades fallidas en kit01 (0)

## 8. Fin del corte
  [ OK ]  Tabla del corte borrada (0)
  [ OK ]  clinica01 llega a Internet otra vez (200)
  [ OK ]  Prerregistro de prueba borrado
  [ OK ]  prueba01 sin portal y apagándose

Resultado: 40 bien y 0 con falla. Salida en /home/melo/8thSem/plats1/kitsalud-movil-plats1/docs/pruebas/salidas/P09-20261102-151256.txt
```

### IPv4

Los nombres resuelven su registro A, DHIS2 y la consulta responden por `10.20.20.11`, el switch llega a la biblioteca por `10.20.20.12` y la VM de la Comunidad abre el portal, la biblioteca, los videos y el registro por IPv4, y envía el prerregistro.

### IPv6

Los nombres resuelven su registro AAAA, DHIS2 y la consulta responden por `fd5a:fc7e:d716:20::11`, el switch llega a la biblioteca por `fd5a:fc7e:d716:20::12` y la VM de la Comunidad abre la redirección al portal, la biblioteca, los videos y el registro por IPv6. Dentro del kit IPv6 no depende de Internet, porque sus direcciones son locales.

## Interpretación

Con Internet cortado, lo externo falló como debía. Un nombre de Internet devolvió `SERVFAIL` y las VMs y la Comunidad no llegaron a `google.com`. Todo lo local siguió funcionando en IPv4 e IPv6. El DNS del kit respondió todos sus nombres, kit01 siguió sincronizado (estrato 3, la última referencia que tenía) y entregando la hora a las VMs, los servicios de la Clínica respondieron por HTTPS con la CA del kit y `ana.rojas` abrió los archivos compartidos. Un equipo nuevo de la Comunidad vio el portal sin Internet, lo aceptó y usó todos los servicios públicos, y su prerregistro quedó guardado en la base de clinica01. El monitoreo no puso en rojo ningún servicio ni ningún equipo durante el corte, y en kit01 ninguna unidad falló. Los contadores de la tabla muestran que el kit intentó salir (DNS hacia afuera, NTP y reenvío) y fue bloqueado. Al quitar la tabla, la salida a Internet volvió sola.

## Resultado

Aprobada. 40 comprobaciones bien y ninguna falla. Queda repetirla en el laboratorio con el cable de la WAN desconectado, con un celular y un PC reales y las capturas de pantalla.
