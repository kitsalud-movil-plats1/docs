# P8 - Tiempo

**Entorno.** Kit real, en remoto por NetBird

## Qué se prueba

Dos o más nodos muestran sincronización con el servicio NTP interno.

**Cómo se probó.** Con `./scripts/P08-tiempo.sh` desde la máquina de control. Revisa kit01 como servidor (Chrony), sus clientes, la sincronización de `clinica01` y `comunidad01`, una consulta directa a kit01 por IPv4 y por IPv6 desde `clinica01` sin cambiar su hora (`chronyd -Q`), el switch sw01 en la red Interna y `prueba01` en la red Comunidad, que recibe el servidor NTP por DHCP como cualquier cliente.

## Comandos y salida

```
== P08 - Tiempo

## kit01, servidor NTP
    Reference ID    : BB31BC09 (187.49.188.9)
    Stratum         : 3
    Ref time (UTC)  : Mon Nov 02 22:01:56 2026
    System time     : 0.000117616 seconds fast of NTP time
    Last offset     : -0.000071840 seconds
    RMS offset      : 0.000279686 seconds
    Frequency       : 20.699 ppm slow
    Residual freq   : -0.001 ppm
    Skew            : 0.050 ppm
    Root delay      : 0.122219488 seconds
    Root dispersion : 0.002306269 seconds
    Update interval : 1038.3 seconds
    Leap status     : Normal
  [ OK ]  kit01 sincronizado (estrato 3; 10 indica modo orphan, sin Internet)
    Hostname                      NTP   Drop Int IntL Last     Cmd   Drop Int  Last
    ===============================================================================
    fd5a:fc7e:d716:20::12       13492      0   6   -  303m       0      0   -     -
    127.0.0.1                       0      0   -   -     -       2      0  14  104m
    10.20.10.2                   4136      0   6   -    37       0      0   -     -
    10.20.40.100                   12      0  11   -    8d       0      0   -     -
    10.20.40.102                    5      0   6   -    6d       0      0   -     -
    10.20.40.104                   12      0   8   -   92h       0      0   -     -
    10.20.40.108                   42      0   6   -   75h       0      0   -     -
    10.20.10.102                   56      0   6   -   74h       0      0   -     -
    10.20.20.12                   192      0   8   -   165       0      0   -     -
    10.20.40.112                    4      0   5   -  266m       0      0   -     -
    10.20.40.114                   12      0   9   -   548       0      0   -     -
    fd5a:fc7e:d716:20::11        9392      0  11   -    16       0      0   -     -
    10.20.40.101                    2      0   1   -    8d       0      0   -     -
    10.20.20.11                  4026      0   8   -    16       0      0   -     -
    10.20.40.103                    3      0   4   -    6d       0      0   -     -
    10.20.40.105                    4      0   5   -   90h       0      0   -     -
    10.20.40.109                   59      0   6   -   74h       0      0   -     -
    10.20.40.113                   12      0   7   -  118m       0      0   -     -
  [ OK ]  kit01 atiende a 10.20.20.11
  [ OK ]  kit01 atiende a fd5a:fc7e:d716:20::12

## clinica01, cliente
    MS Name/IP address         Stratum Poll Reach LastRx Last sample
    ===============================================================================
    ^* 10.20.20.10                   3   6   377    46  -1585ns[ -182us] +/-   63ms
    Reference ID    : 0A14140A (ns1.salud.movil)
    Stratum         : 4
    Ref time (UTC)  : Mon Nov 02 22:14:29 2026
    System time     : 0.000000196 seconds fast of NTP time
    Last offset     : -0.000180516 seconds
    RMS offset      : 0.000059760 seconds
    Frequency       : 20.845 ppm slow
    Residual freq   : -0.034 ppm
    Skew            : 0.152 ppm
    Root delay      : 0.122622505 seconds
    Root dispersion : 0.001842889 seconds
    Update interval : 257.0 seconds
    Leap status     : Normal
  [ OK ]  clinica01 usa kit01 como fuente (^*)
          Desfase de clinica01 con kit01: 0.000000196 seconds fast of NTP time

## comunidad01, cliente
    MS Name/IP address         Stratum Poll Reach LastRx Last sample
    ===============================================================================
    ^* 10.20.20.10                   3   8   377   177  -1943ns[  -88us] +/-   63ms
    Reference ID    : 0A14140A (ns1.salud.movil)
    Stratum         : 4
    Ref time (UTC)  : Mon Nov 02 22:12:26 2026
    System time     : 0.000000036 seconds fast of NTP time
    Last offset     : -0.000086317 seconds
    RMS offset      : 0.000030044 seconds
    Frequency       : 20.762 ppm slow
    Residual freq   : -0.093 ppm
    Skew            : 0.096 ppm
    Root delay      : 0.122652955 seconds
    Root dispersion : 0.001927111 seconds
    Update interval : 258.0 seconds
    Leap status     : Normal
  [ OK ]  comunidad01 usa kit01 como fuente (^*)
          Desfase de comunidad01 con kit01: 0.000000036 seconds fast of NTP time

## Consulta a kit01 por IPv4 e IPv6 desde clinica01, sin cambiar su hora
          10.20.20.10: System clock wrong by -0.000008 seconds (ignored)
  [ OK ]  kit01 responde NTP por 10.20.20.10
          fd5a:fc7e:d716:20::10: System clock wrong by -0.000144 seconds (ignored)
  [ OK ]  kit01 responde NTP por fd5a:fc7e:d716:20::10

## sw01 (red Interna), cliente
             servers: 10.20.20.10
              status: synchronized
       synced-server: 10.20.20.10
      synced-stratum: 3
       system-offset: -0.929 ms
  [ OK ]  sw01 sincronizado con kit01 (synchronized 10.20.20.10)

## prueba01 (Comunidad), cliente que recibe el NTP por DHCP
    ServerAddress=10.20.20.10
    NTPSynchronized=yes
  [ OK ]  prueba01 toma la hora de kit01 (ServerAddress=10.20.20.10 NTPSynchronized=yes)

Resultado: 9 bien y 0 con falla.
```

### IPv4

`clinica01` y `comunidad01` tienen a `10.20.20.10` (kit01) como fuente elegida (`^*`) con desfases de microsegundos, sw01 está sincronizado con `10.20.20.10` con un desfase de menos de un milisegundo y `prueba01` toma la hora de `10.20.20.10`, la dirección que le entregó el DHCP. La lista de clientes de kit01 muestra además clientes de las redes Interna (`10.20.10.x`) y Comunidad (`10.20.40.x`).

### IPv6

kit01 respondió por `fd5a:fc7e:d716:20::10` a la consulta de `clinica01`, con una diferencia de 0,14 ms con su reloj, y la lista de clientes de kit01 muestra a `fd5a:fc7e:d716:20::11` y `fd5a:fc7e:d716:20::12`, que también lo han consultado por IPv6.

## Interpretación

Las dos VMs, el switch y un cliente de la Comunidad toman la hora de kit01, y la lista de clientes de kit01 muestra otros equipos que pasaron por las redes Interna y Comunidad. kit01 sirve la hora en IPv4 e IPv6. kit01 está en estrato 3 porque se sincroniza con servidores de Internet. Sin Internet sigue sirviendo la hora con la última referencia que tenía y, si pasa mucho tiempo, pasa a estrato 10 (modo huérfano) y todos los equipos siguen de acuerdo entre sí. Con la hora igual en todos los equipos, los registros del log central se pueden comparar y el directorio acepta las autenticaciones con Kerberos, que fallan si los relojes difieren más de cinco minutos.

## Resultado

Aprobada. 9 comprobaciones bien y ninguna falla. En la sustentación se puede revisar el desfase de un PC del sitio con `./scripts/P08-tiempo.sh --estacion`.
