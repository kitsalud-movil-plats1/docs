# P1 - Cliente comunitario

**Fecha.** 2026-11-02, 16:44 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird · **Versión.** `docs` `ddb5f1f`, `network` `1133967`, `platform` `025b11c`

## Qué se prueba

Un dispositivo que se conecta a la red Comunidad obtiene IPv4 e IPv6, DNS y gateway.

**Cómo se probó.** El cliente es `prueba01`, una máquina virtual de kit01 conectada al puente de la red Comunidad (VLAN 40), la misma red que el SSID `SaludMovil-Comunidad`. Recibe la configuración igual que un celular, por DHCPv4 y por los anuncios de router de IPv6, y no tiene nada configurado a mano. El script `P01-cliente.sh` se ejecutó dentro de ella con `./scripts/en-prueba01.sh P01-cliente.sh`, desde la máquina de control.

## Comandos y salida

```
== P01 - Cliente comunitario
Fecha 2026-11-02 16:44:17 -0500 · equipo prueba01 · Linux
          Interfaz eth0, red comunidad (VLAN 40)

## Configuración recibida
    2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
        link/ether 52:54:00:40:00:50 brd ff:ff:ff:ff:ff:ff
        inet 10.20.40.114/24 metric 100 brd 10.20.40.255 scope global dynamic eth0
           valid_lft 3399sec preferred_lft 3399sec
        inet6 fd5a:fc7e:d716:40:5054:ff:fe40:50/64 scope global dynamic mngtmpaddr noprefixroute
           valid_lft 86211sec preferred_lft 14211sec
        inet6 fe80::5054:ff:fe40:50/64 scope link
           valid_lft forever preferred_lft forever
    default via 10.20.40.1 dev eth0 proto dhcp src 10.20.40.114 metric 100
    10.20.20.10 via 10.20.40.1 dev eth0 proto dhcp src 10.20.40.114 metric 100
    10.20.40.0/24 dev eth0 proto kernel scope link src 10.20.40.114 metric 100
    10.20.40.1 dev eth0 proto dhcp scope link src 10.20.40.114 metric 100
    fd5a:fc7e:d716:40::/64 dev eth0 proto ra metric 100 expires 86210sec hoplimit 64 pref medium
    fe80::/64 dev eth0 proto kernel metric 256 pref medium
    default via fe80::1 dev eth0 proto ra metric 100 expires 1610sec hoplimit 64 pref medium
    Link 2 (eth0)
        Current Scopes: DNS
             Protocols: +DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
    Current DNS Server: 10.20.20.10
           DNS Servers: 10.20.20.10 fd5a:fc7e:d716:20::10
            DNS Domain: salud.movil

## IPv4 (Kea DHCPv4)
  [ OK ]  Dirección 10.20.40.114 del rango del kit
  [ OK ]  Gateway IPv4 (10.20.40.1)
  [ OK ]  El gateway responde al ping IPv4

## IPv6 (SLAAC con el anuncio de radvd)
  [ OK ]  Dirección fd5a:fc7e:d716:40:5054:ff:fe40:50 del prefijo fd5a:fc7e:d716:40::/64
  [ OK ]  Gateway IPv6 (fe80::1)
  [ OK ]  El gateway responde al ping IPv6 (fe80::1%eth0)

## DNS (DHCPv4 y DHCPv6 stateless)
          Servidores: 10.20.20.10 fd5a:fc7e:d716:20::10
  [ OK ]  DNS IPv4 del kit (10.20.20.10)
  [ OK ]  DNS IPv6 del kit (fd5a:fc7e:d716:20::10)
  [ OK ]  Resuelve portal.salud.movil (10.20.40.1)

Resultado: 9 bien y 0 con falla.
```

### IPv4

El servidor DHCPv4 de kit01 entregó `10.20.40.114/24`, dentro del rango de clientes de la Comunidad (`.100` a `.250`), con una concesión de una hora, el gateway `10.20.40.1`, el DNS `10.20.20.10` y el dominio `salud.movil`. El gateway responde al ping.

### IPv6

El anuncio de router de kit01 en la VLAN 40 dio el prefijo `fd5a:fc7e:d716:40::/64`, del que el cliente formó su dirección por SLAAC, y la ruta por defecto hacia `fe80::1`, la dirección de enlace de kit01. El DNS IPv6 `fd5a:fc7e:d716:20::10` llegó por DHCPv6 sin estado. El gateway responde al ping por IPv6.

## Interpretación

Un equipo nuevo de la Comunidad queda listo para usar el kit sin configuración manual. Tiene dirección, gateway y DNS en las dos familias, y los servidores DNS que recibe son los del kit, así que los nombres de `salud.movil` resuelven desde el primer momento.

## Resultado

Aprobada. 9 comprobaciones bien y ninguna falla. En la sustentación se repite con un celular en cada SSID, que además muestra que ningún cliente recibe una dirección `192.168.0.x` del punto de acceso.
