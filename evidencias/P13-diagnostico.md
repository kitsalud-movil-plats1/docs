# P13 - Diagnóstico

**Entorno.** Kit real, en remoto por NetBird

## Qué se prueba

Al simular una falla, se usan los logs y los comandos para localizarla y explicar el impacto. Se provocaron tres fallas, una a la vez. Se detuvo el DNS de kit01, se detuvo la base de datos de la historia clínica y se apagó la VM de la comunidad.

El kit vigila cada servicio desde kit01. Prometheus prueba cada servicio cada 15 segundos en IPv4 y en IPv6, y lee el estado de los servicios críticos de cada equipo; un servicio que falla 30 segundos seguidos genera una alerta. Grafana lo muestra en el tablero **Estado del kit**. Los logs de todos los equipos llegan a kit01, a una carpeta por equipo en `/var/log/kitsalud/`.

## Comandos y salida

Se ejecutó `./scripts/P13-diagnostico.sh <falla>` en la máquina de control para cada falla. El script muestra las alertas de antes, provoca la falla, espera 75 segundos, junta las alertas, el síntoma, la causa y el log central, restaura y comprueba que las alertas se apagan.

### Falla 1. DNS detenido en kit01 (`systemctl stop named`)

```
## Antes
        (sin alertas)

## Falla inducida en kit01: systemctl stop named
    15:19:23 falla inducida; esperando 75 s a que Prometheus la detecte

## Lo que ve el administrador
    ServicioCaido kit01 dns ipv6 firing
    ServicioCaido kit01 dns ipv4 firing
    ServicioCaido kit01 dns ipv6 firing
    ServicioCaido kit01 dns ipv4 firing
    ServicioCaido kit01 dns ipv4 firing
    ServicioCaido kit01 dns ipv6 firing
  [ OK ]  Prometheus detectó la falla
    Síntoma:
      ;; communications error to 10.20.20.10#53: connection refused
    Causa:
      ○ named.service - BIND Domain Name Server
           Loaded: loaded (/usr/lib/systemd/system/named.service; enabled; preset: enabled)
           Active: inactive (dead) since Mon 2026-11-02 15:19:23 -05; 1min 32s ago
         Duration: 6d 4h 45min 1.318s
             Docs: man:named(8)
      stopping command channel on ::1#953
      exiting
      named.service: Deactivated successfully.
      Stopped named.service - BIND Domain Name Server.
      named.service: Consumed 2min 12.047s CPU time, 84.0M memory peak, 4.0K memory swap peak.
      UNCONN 0      0                              127.0.0.54:53                                    0.0.0.0:*    users:(("systemd-resolve",pid=180854,fd=16))
      UNCONN 0      0                           127.0.0.53%lo:53                                    0.0.0.0:*    users:(("systemd-resolve",pid=180854,fd=14))
      UNCONN 0      0                          100.90.225.113:53                                    0.0.0.0:*    users:(("netbird",pid=3193,fd=6))           
    Log central:
      2026-11-02T15:19:23.030287-05:00 kit01 named[265632]: stopping command channel on 127.0.0.1#953
      2026-11-02T15:19:23.030329-05:00 kit01 named[265632]: stopping command channel on ::1#953
      2026-11-02T15:19:23.042156-05:00 kit01 named[265632]: exiting

## Restauración: systemctl start named
    15:21:05 restaurado; esperando 90 s
        (sin alertas)
  [ OK ]  Las alertas de la falla se apagaron

Resultado: 2 bien y 0 con falla.
```

### Falla 2. Base de datos de la historia clínica detenida (`docker stop dhis2-db-1` en clinica01)

```
## Antes
        (sin alertas)

## Falla inducida en clinica01: docker stop dhis2-db-1
    15:22:57 falla inducida; esperando 75 s a que Prometheus la detecte

## Lo que ve el administrador
    ServicioCaido clinica01 postgresql ipv6 firing
    ServicioCaido clinica01 postgresql ipv4 firing
  [ OK ]  Prometheus detectó la falla
    Síntoma:
      DHIS2 responde 302
    Causa:
      dhis2-db-1 Exited (0) About a minute ago
      	at org.postgresql.core.PGStream.<init>(PGStream.java:131)
      	at org.postgresql.core.v3.ConnectionFactoryImpl.tryConnect(ConnectionFactoryImpl.java:221)
      	at org.postgresql.core.v3.ConnectionFactoryImpl.openConnectionImpl(ConnectionFactoryImpl.java:367)
      	... 13 more
      * WARN  2026-11-02T20:24:20,059 Having failed to acquire a resource, com.mchange.v2.resourcepool.BasicResourcePool@21a5624a is interrupting all Threads waiting on a resource to check out. Will try again in response to new client requests. (Slf4jMLog.java [C3P0PooledConnectionPoolManager[identityToken->1br8av6bl17mqz1zq0a8eq|31003b3a]-HelperThread-#2])  
    Log central:
      2026-11-02T15:22:56.600611-05:00 clinica01 containerd[809]: time="2026-11-02T15:22:56.600408549-05:00" level=info msg="cleaning up after shim disconnected" id=d52286cb0043bb4b0ade07220a8cc4b315019c0d8
      2026-11-02T15:22:56.600620-05:00 clinica01 containerd[809]: time="2026-11-02T15:22:56.600425089-05:00" level=info msg="cleaning up dead shim" id=d52286cb0043bb4b0ade07220a8cc4b315019c0d8923cabea43cf27
      2026-11-02T15:22:56.614331-05:00 clinica01 dockerd[946]: time="2026-11-02T15:22:56.614201523-05:00" level=warning msg="ShouldRestart failed, container will not be restarted" container=d52286cb0043bb4b

## Restauración: docker start dhis2-db-1
    15:24:39 restaurado; esperando 90 s
        (sin alertas)
  [ OK ]  Las alertas de la falla se apagaron

Resultado: 2 bien y 0 con falla.
```

### Falla 3. VM de la comunidad apagada (`virsh shutdown comunidad01` en kit01)

```
## Antes
        (sin alertas)

## Falla inducida en kit01: virsh -c qemu:///system shutdown comunidad01
    15:26:25 falla inducida; esperando 75 s a que Prometheus la detecte

## Lo que ve el administrador
    ServicioCaido comunidad01 ping ipv6 firing
    ServicioCaido comunidad01 biblioteca ipv4 firing
    ServicioCaido comunidad01 ca ipv6 firing
    ServicioCaido comunidad01 registro ipv6 firing
    ServicioCaido comunidad01 biblioteca ipv6 firing
    ServicioCaido comunidad01 ca ipv4 firing
    ServicioCaido comunidad01 registro ipv4 firing
    ServicioCaido comunidad01 videos ipv6 firing
    ServicioCaido comunidad01 ping ipv4 firing
    ServicioCaido comunidad01 ssh ipv4 firing
    ServicioCaido comunidad01 videos ipv4 firing
    ServicioCaido comunidad01 ssh ipv6 firing
    ExporterCaido comunidad01   firing
  [ OK ]  Prometheus detectó la falla
    Síntoma:
      La biblioteca responde 000
      La biblioteca no responde
      comunidad01 no responde al ping
    Causa:
       20   clinica01     running
       -    comunidad01   shut off
      shut off (shutdown)
    Log central:
      2026-11-02T15:26:25.347334-05:00 comunidad01 systemd[1]: Stopping ssh.service - OpenBSD Secure Shell server...
      2026-11-02T15:26:25.347393-05:00 comunidad01 systemd[1]: sysstat.service: Deactivated successfully.
      2026-11-02T15:26:25.347438-05:00 comunidad01 systemd[1]: Stopped sysstat.service - Resets System Activity Logs.

## Restauración: virsh -c qemu:///system start comunidad01
    15:28:10 restaurado; esperando 90 s
        (sin alertas)
  [ OK ]  Las alertas de la falla se apagaron

Resultado: 2 bien y 0 con falla.
```

### IPv4 e IPv6

Cada servicio se prueba en las dos familias, así que cada falla aparece dos veces en las alertas, una con `ipv4` y otra con `ipv6`. Las tres fallas se vieron en las dos familias.

## Interpretación

**DNS detenido.** Las sondas de DNS se pusieron en rojo en IPv4 e IPv6. Una consulta a `10.20.20.10` respondió `connection refused`, `systemctl status named` mostró el servicio detenido y a qué hora, `ss` confirmó que nada escuchaba en el puerto 53 del kit y el log central registró la salida de BIND9. El impacto es que los clientes y las VMs dejan de resolver los nombres del kit y de Internet; los servicios siguen arriba y se puede llegar a ellos por dirección IP. Se restauró con `systemctl start named`.

**Base de datos detenida.** Las sondas de PostgreSQL se pusieron en rojo en las dos familias. `docker ps` mostró el contenedor de la base detenido y el log del contenedor de DHIS2 sus intentos fallidos de conexión. La sonda de DHIS2 siguió en verde, porque su página responde aunque no tenga base. El impacto es que nadie puede iniciar sesión ni consultar o registrar pacientes en DHIS2, y el formulario de la comunidad avisa que no pudo guardar. Se restauró con `docker start dhis2-db-1`.

**VM de la comunidad apagada.** Doce alertas de comunidad01 (biblioteca, videos, registro, la página de la CA, SSH y ping, cada una en IPv4 e IPv6) y otra porque no se podían leer sus métricas. `virsh` mostró la VM en `shut off (shutdown)`, es decir, apagada de forma ordenada, y su log central terminaba con los servicios deteniéndose. El impacto es que la comunidad pierde la biblioteca, los videos y el formulario, mientras la atención clínica sigue normal. Se restauró con `virsh start comunidad01` y los servicios volvieron solos.

## Resultado

Aprobada. Las tres fallas se detectaron, se localizaron con el monitoreo, los comandos y el log central, y al restaurar todas las alertas se apagaron (6 comprobaciones bien y ninguna falla).
