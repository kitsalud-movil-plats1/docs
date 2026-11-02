# P12 - Reinicio

**Fecha.** 2026-11-02, de 16:28 a 16:40 (hora de Colombia) · **Entorno.** Kit real, en remoto por NetBird · **Versión.** `docs` `a0a1452`, `network` `1133967`, `platform` `025b11c`, `apps` `3969c3b`, `observability` `43b7ed6`

## Qué se prueba

Se reinicia un equipo y los servicios críticos se activan sin intervención manual.

Se reiniciaron a la vez `clinica01` y `comunidad01`, las dos máquinas virtuales que tienen todos los servicios de aplicación. `clinica01` tiene la historia clínica (DHIS2 con PostgreSQL), la consulta de prerregistros, el directorio (Samba AD) y los archivos compartidos. `comunidad01` tiene la biblioteca, los videos, el formulario de prerregistro y la página de la CA. kit01 siguió encendido, así que el acceso remoto no corrió riesgo.

Al arrancar, libvirt no interviene porque la VM se reinicia sola. Docker levanta los contenedores con `restart: unless-stopped` y el orden entre ellos lo resuelven las aplicaciones, con healthchecks, `depends_on` y reintentos. Samba AD arranca con systemd.

**Cómo se midió.** El script reinicia las dos VMs con `virsh reboot` y desde kit01 consulta Prometheus cada 2 segundos. Prometheus prueba cada 15 segundos 39 servicios por IPv4 e IPv6 (DNS, HTTPS de DHIS2, de la consulta y del registro, HTTP de la biblioteca, los videos, la CA y el portal, SMB, PostgreSQL, LDAPS, SSH y ping) y lee los exporters de los tres equipos. Una familia cuenta como recuperada cuando se vio en rojo y vuelve a tener todas sus sondas en verde. El tiempo total va desde el reinicio hasta que no queda nada en rojo.

## Comandos y salida

Se ejecutó `./scripts/P12-reinicio.sh vms` en la máquina de control.

**Antes.** kit01 sin unidades fallidas y con todos sus servicios activos, las dos VMs en marcha, todos los contenedores arriba y ninguna sonda en rojo.

```
## clinica01
    encendida desde 2026-11-02 12:13:16
    dhis2-core-1 Up 4 hours (healthy)
    dhis2-db-1 Up About an hour (healthy)
    consultas-app-1 Up 4 hours (healthy)
    caddy-caddy-1 Up 4 hours
  [ OK ]  Todos los contenedores de clinica01 arriba
  [ OK ]  Sin unidades fallidas en clinica01
  [ OK ]  Samba AD activo

## comunidad01
    encendida desde 2026-11-02 15:28:10
    jellyfin-jellyfin-1 Up About an hour (healthy)
    formularios-app-1 Up About an hour (healthy)
    caddy-caddy-1 Up About an hour
    kiwix-kiwix-1 Up About an hour
  [ OK ]  Todos los contenedores de comunidad01 arriba
  [ OK ]  Sin unidades fallidas en comunidad01

## Monitoreo
  [ OK ]  Sondas y exporters en rojo (0)
```

**Reinicio.**

```
## Reinicio de clinica01 y comunidad01
    reinicio de clinica01 y comunidad01 a las 16:31:10
    ipv4 en rojo a los 2 s (1 sondas)
    ipv6 en rojo a los 2 s (1 sondas)
    exporters de las VMs en rojo a los 9 s
    exporters de las VMs en verde a los 21 s
    ipv6 en verde a los 42 s
    ipv4 en verde a los 44 s
    todo en verde a los 44 s
  [ OK ]  Sondas ipv4 en verde otra vez a los 44 s
  [ OK ]  Sondas ipv6 en verde otra vez a los 42 s
  [ OK ]  Todo en verde a los 44 s del reinicio, sin intervención
          Esperando 30 s para revisar que nada se cae después del arranque
```

**Después.**

```
## kit01
     16:32:28 up 24 days,  2:18,  2 users,  load average: 0.60, 0.39, 0.25
    6.8.0-139-generic
          systemd-networkd-wait-online figura fallida desde el último arranque de kit01, anterior a la red actual
  [ OK ]  Sin unidades fallidas en kit01
  [ OK ]  nftables activo
  [ OK ]  kea-dhcp4-server activo
  [ OK ]  kea-dhcp6-server activo
  [ OK ]  radvd activo
  [ OK ]  named activo
  [ OK ]  chrony activo
  [ OK ]  nginx activo
  [ OK ]  kitsalud-portal activo
  [ OK ]  prometheus activo
  [ OK ]  grafana-server activo
  [ OK ]  rsyslog activo
  [ OK ]  netbird activo
  [ OK ]  libvirtd activo
  [ OK ]  VM clinica01 en marcha
  [ OK ]  VM comunidad01 en marcha

## clinica01
    encendida desde 2026-11-02 16:31:13
    dhis2-core-1 Up 2 minutes (healthy)
    dhis2-db-1 Up 2 minutes (healthy)
    consultas-app-1 Up 2 minutes (healthy)
    caddy-caddy-1 Up 2 minutes
  [ OK ]  Todos los contenedores de clinica01 arriba
  [ OK ]  Sin unidades fallidas en clinica01
  [ OK ]  Samba AD activo

## comunidad01
    encendida desde 2026-11-02 16:31:12
    jellyfin-jellyfin-1 Up 2 minutes (healthy)
    formularios-app-1 Up 2 minutes (healthy)
    caddy-caddy-1 Up 2 minutes
    kiwix-kiwix-1 Up 2 minutes
  [ OK ]  Todos los contenedores de comunidad01 arriba
  [ OK ]  Sin unidades fallidas en comunidad01

## Monitoreo
  [ OK ]  Sondas y exporters en rojo (0)

Resultado: 47 bien y 0 con falla.
```

**Cierre de la base de datos.** En el registro de PostgreSQL de `clinica01` el cierre fue ordenado y el arranque no necesitó recuperación.

```
$ docker logs dhis2-db-1 --since 10m | grep -E 'shut down|ready'
2026-11-02 21:31:11.096 UTC [1] LOG:  database system is shut down
2026-11-02 21:31:21.356 UTC [27] LOG:  database system was shut down at 2026-11-02 21:31:11 UTC
2026-11-02 21:31:21.379 UTC [1] LOG:  database system is ready to accept connections
```

**Matriz de flujos después del arranque.** `ansible-playbook playbooks/verificar-flujos.yml` probó de nuevo los flujos permitidos y bloqueados desde kit01, las VMs, `prueba01` y sw01.

```
TASK [Todos los flujos como se esperaba] ***************************************
ok: [kit01] => {
    "changed": false,
    "msg": "69 pruebas, todas como se esperaba"
}
```

### IPv4

Las sondas de IPv4 se pusieron en rojo a los 2 segundos del reinicio y volvieron todas a verde a los 44 segundos. Entre ellas están DHIS2, la consulta y el registro por HTTPS con la CA del kit, la biblioteca, los videos, la CA y el portal por HTTP, SMB, PostgreSQL, LDAPS, el DNS y el ping a las VMs.

### IPv6

Las mismas sondas por IPv6 se pusieron en rojo a los 2 segundos y volvieron a verde a los 42 segundos. Las dos familias volvieron casi al mismo tiempo porque los servicios escuchan en las dos desde el arranque.

## Interpretación

Las dos VMs se reiniciaron con un cierre ordenado. PostgreSQL registró `database system is shut down` y al arrancar no tuvo que recuperar nada. A los 44 segundos de la orden de reinicio todos los servicios respondían otra vez por IPv4 e IPv6, sin que nadie arrancara nada a mano. Los contenedores de las dos VMs quedaron `healthy`, Samba AD activo y ninguna unidad fallida. Treinta segundos después el estado seguía igual, y las 69 pruebas de la matriz de flujos dieron lo esperado, así que las VMs volvieron también con su firewall. kit01 no se tocó, así que la red, el firewall, el DNS, la hora y el monitoreo siguieron funcionando durante la prueba.

En el registro de `clinica01`, Samba AD termina con el código 127 cada vez que systemd lo detiene, en esta prueba y en todas las paradas anteriores. Después de esas paradas `samba-tool dbcheck` no encuentra errores, y el servicio arrancó normal, como muestra el estado después.

## Resultado

Aprobada. 47 comprobaciones bien y ninguna falla, con todos los servicios en verde a los 44 segundos del reinicio. En la sustentación se puede repetir con el reinicio de kit01 (`./scripts/P12-reinicio.sh reiniciar`), que además vuelve a armar las redes, el firewall y las VMs desde el arranque.
