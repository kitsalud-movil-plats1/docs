# Equipos de red

Esta parte conecta los equipos y deja configurados el switch (sw01) y el punto de acceso (ap01). Los dos se configuran desde un portátil conectado directamente a cada uno, así que pueden quedar listos antes de instalar kit01. Su comprobación en remoto se hace en la [comprobación final](verificacion.md), cuando kit01 ya enruta la red Interna.

## Cableado

| Desde | Hasta | Qué lleva |
|---|---|---|
| kit01 `enp170s0` | Red del sitio (uplink con Internet) | WAN. Por aquí entra también NetBird |
| kit01 `enp171s0` | sw01 `ether1` | Trunk con las VLAN 10 (Interna) y 40 (Comunidad), solo etiquetadas. sw01 también tiene la VLAN 20 en este puerto, pero kit01 solo la usa en el perfil con un equipo más |
| sw01 `ether2` | Puerto LAN del inyector PoE del AP | Wi-Fi de la Interna (VLAN 10) y de la Comunidad (VLAN 40) |
| Inyector PoE, puerto PoE | ap01 | Alimentación y datos del AP |
| sw01 `ether4` a `ether8` | Estaciones de la clínica | Interna (VLAN 10) sin etiqueta |
| Disco USB de copias | Un puerto USB 3.0 de kit01 | Repositorio de restic |

`ether3` queda deshabilitado y del `ether9` en adelante quedan fuera del bridge.

## Switch sw01 (MikroTik CCR2004)

La configuración completa está en `network/switch/sw01.rsc`, exportada con `/export terse`. Se aplica sobre un switch sin configuración, por la consola serial, para no perder el acceso mientras cambian las VLAN.

| Qué deja | Valor |
|---|---|
| Bridge | `bridge-kit` con filtrado de VLAN y DHCP snooping, con `ether1-kit01` como único puerto de confianza |
| Puertos | `ether1-kit01` trunk, `ether2-ap01` con 10 y 40 etiquetadas y sin etiqueta en la 10 (la gestión del AP responde sin etiqueta), `ether4` a `ether8` de acceso en la VLAN 10 |
| Gestión | `vlan10-Interna` con `10.20.10.2/24` y `fd5a:fc7e:d716:10::2/64`, gateway `10.20.10.1` y `fe80::1` |
| Servicios | Solo SSH y Winbox, desde `10.20.10.1` y las direcciones de administración `10.20.10.10` a `10.20.10.29`. Telnet, FTP, web y API apagados |
| Protección | Sin reenvío IPv4 ni IPv6 y descarte de los anuncios de router (IPv6 a `ff02::1`) que entren por los puertos de acceso |
| Hora y logs | Zona `America/Bogota`, NTP desde `10.20.20.10` y syslog por UDP hacia `10.20.20.10` |

**Pasos**

1. Conectar el cable de consola al puerto serial RJ45 del switch y abrir la terminal a 115200 8N1.

   ```bash
   sudo picocom -b 115200 /dev/ttyUSB0
   ```

2. Entrar como `admin` y dejar el switch sin configuración. Se reinicia solo.

   ```
   /system reset-configuration no-defaults=yes skip-backup=yes
   ```

3. Subir `sw01.rsc` al switch. Con el switch sin IP, se conecta el portátil a `ether3` y se abre Winbox por la MAC (pestaña **Neighbors**), y el archivo se arrastra a **Files**. También sirve pegar el contenido del archivo en la consola, de a unas pocas líneas.
4. Aplicarlo desde la consola serial.

   ```
   /import file-name=sw01.rsc
   ```

5. Poner la contraseña del usuario `admin`, que está en el vault como `vault_sw01_password`. El archivo no la trae, porque `/export` omite los datos sensibles.

   ```
   /user set admin password="<contraseña del vault>"
   ```

6. Conectar los cables de la tabla de cableado.

**Cómo comprobarlo en la consola**

```
/interface bridge vlan print       # VLAN 10 y 40 con los puertos de la tabla, y la 20 en ether1 y ether3
/ip address print                  # 10.20.10.2/24 en vlan10-Interna
/ip service print                  # solo ssh y winbox habilitados
```

## Punto de acceso ap01 (TP-Link TL-WA801ND v3)

El AP no tiene línea de comandos, así que se configura en su interfaz web con los valores de esta tabla. Después se revisa en remoto con `network/ap/revisar-ap.sh`, que lee las mismas páginas y no cambia nada.

| Menú | Parámetro | Valor |
|---|---|---|
| Wireless → Wireless Settings | Modo de operación | Multi-SSID con **Enable VLAN** |
| Wireless → Wireless Settings | SSID1 | `SaludMovil-Clinica`, VLAN 10 |
| Wireless → Wireless Settings | SSID2 | `SaludMovil-Comunidad`, VLAN 40 |
| Wireless → Wireless Settings | SSID3 y SSID4 | Desactivados |
| Wireless → Wireless Settings | Región, modo y canal | Colombia, 11bgn mixed, 20 MHz, canal automático |
| Wireless → Wireless Security | SSID1 | WPA2-PSK con AES y la clave del Wi-Fi de la clínica |
| Wireless → Wireless Security | SSID2 | En el laboratorio, WPA2-PSK con AES y su propia clave. En una misión, sin seguridad (la protege el portal cautivo de kit01) |
| Wireless → Wireless Advanced | AP Isolation y Short GI | Activados (el aislamiento solo actúa en el SSID1) |
| DHCP → DHCP Settings | Servidor DHCP | Desactivado (las direcciones las entrega kit01) |
| WPS y System Tools → SNMP | WPS y SNMP | Desactivados |
| Network → LAN | IP | Fija, `10.20.10.3/24`, gateway `10.20.10.1` |
| Network → LAN | Allow remote access | Desactivado |
| System Tools → Password | Contraseña de administración | La del vault, `vault_ap01_password` |

**Pasos**

1. Conectar el AP con su inyector PoE solo al portátil, poner en el portátil la dirección fija `192.168.0.10/24` y abrir `http://192.168.0.254`. Si el AP ya tenía otra configuración, se restablece manteniendo el botón **Reset** unos 5 segundos con el equipo encendido.
2. Desactivar primero el servidor DHCP, WPS y SNMP.
3. Configurar el modo Multi-SSID con VLAN, los SSID, su seguridad, la región y AP Isolation.
4. Al final, cambiar la IP a `10.20.10.3`. El AP se reinicia y deja de responder en el portátil.
5. Guardar una copia de la configuración desde **System Tools → Backup & Restore**, fuera del repositorio, porque contiene la clave del Wi-Fi.
6. Conectar el puerto LAN del inyector a `ether2` de sw01.

**Cómo comprobarlo.** Con kit01 desplegado, desde `network/` en la máquina de control, `./ap/revisar-ap.sh` termina con `17 bien y 0 con falla`.
