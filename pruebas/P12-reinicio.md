# P12 - Reinicio

## Qué se prueba

**Enunciado.** Se reinicia un equipo y los servicios críticos se activan sin intervención manual.

Se prueba en remoto reiniciando las dos VMs a la vez, que tienen todos los servicios de aplicación. Al arrancar, Docker levanta los contenedores con `restart: unless-stopped` y el orden lo resuelven las aplicaciones (healthchecks, `depends_on` y reintentos). Samba AD arranca con systemd. kit01 sigue encendido, así que el acceso remoto no corre riesgo.

kit01 es el router, el firewall y el hipervisor. Al arrancar levantan solos nftables, la red, Kea, radvd, BIND9, Chrony, nginx, el portal, Prometheus, Grafana, rsyslog y NetBird, y libvirt arranca las VMs con `autostart`. Su reinicio se muestra en la sustentación si hay tiempo para esperar que vuelva, y también activa el kernel 6.8.0-147.

## Reinicio de las VMs (en remoto)

Desde `docs/pruebas/`, en la máquina de control.

```bash
./scripts/P12-reinicio.sh vms
```

El script revisa el estado, reinicia `clinica01` y `comunidad01` con `virsh reboot` y sigue en Prometheus, cada 2 segundos, la caída y la vuelta de las sondas de IPv4, las de IPv6 y los exporters de las VMs. Una familia cuenta como recuperada cuando se vio en rojo y vuelve a tener todas sus sondas en verde. El tiempo total va desde el reinicio hasta que no queda nada en rojo. Después espera 30 s y revisa otra vez el estado completo. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P12-<fecha>.txt`.

Al final se comprueba la matriz de flujos desde `platform/ansible`.

```bash
ansible-playbook playbooks/verificar-flujos.yml
```

## Reinicio de kit01 (en la sustentación)

Con alguien en el sitio por si kit01 no vuelve. Se hace una sola vez y al final.

1. Anotar el estado antes (comandos de abajo) y la hora.
2. Reiniciar kit01 desde remoto con `ssh kitsalud@100.90.225.113 sudo reboot`.
3. Esperar 3-5 minutos. sw01 y el AP siguen encendidos.
4. Cuando NetBird responda (`ping 100.90.225.113`), revisar el estado después.
5. En el sitio, conectar un celular a la Comunidad. El portal vuelve a salir, porque las autorizaciones no sobreviven al reinicio, y después abren la biblioteca y los videos.
6. Si en 10 minutos no responde, en el sitio revisar la luz de kit01, mantener el botón 5 s, soltar y encender.

Con el script, desde la máquina de control.

```bash
./scripts/P12-reinicio.sh estado
./scripts/P12-reinicio.sh reiniciar
```

`estado` revisa unidades fallidas (por nombre), los servicios críticos de kit01, las VMs, los contenedores, Samba AD y las sondas en rojo. `reiniciar` hace lo mismo, reinicia kit01 (pide confirmación), mide cuánto tarda en volver y revisa otra vez. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Dónde | Comando | Qué muestra | Esperado después |
|---|---|---|---|
| kit01 | `uptime` y `uname -r` | Que reinició y con qué kernel | Minutos encendido; `6.8.0-147-generic` |
| kit01 | `systemctl --failed` | Unidades que fallaron al arrancar | `0 loaded units listed` |
| kit01 | `systemctl is-active nftables kea-dhcp4-server kea-dhcp6-server radvd named chrony nginx kitsalud-portal prometheus grafana-server rsyslog netbird libvirtd` | Los servicios críticos de kit01 | `active` en todos |
| kit01 | `sudo nft list ruleset \| grep -c chain` | Que el firewall cargó | El mismo número que antes |
| kit01 | `virsh -c qemu:///system list` | Las VMs con autostart | `clinica01` y `comunidad01` `running` |
| clinica01 | `docker ps --format '{{.Names}} {{.Status}}'` y `systemctl is-active samba-ad-dc` | Los contenedores y Samba | Todos `Up`, `healthy`; `active` |
| comunidad01 | `docker ps --format '{{.Names}} {{.Status}}'` | Los contenedores | Todos `Up` |
| kit01 | `systemctl list-timers backup.timer` | Que el backup quedó programado | El próximo domingo |
| Grafana | **Estado del kit** | Que todo volvió | Todo en verde |
| Laptop | `ansible-playbook playbooks/verificar-flujos.yml` | La matriz de flujos completa tras el arranque | Todos los flujos como se esperan |

`systemctl --failed` es lo más rápido: si una unidad crítica no arrancó, aparece ahí.

**macOS.** Igual que P11, con Ansible y `sshpass` instalados.

**La espera de la red.** `systemd-networkd-wait-online.service` figura fallida desde el arranque del 9 de octubre, anterior a la red actual del kit, porque al arrancar se acabó el tiempo de espera de las interfaces. Las interfaces están bien (`networkctl list`, todas `configured`) y el script lo muestra como nota hasta que kit01 se reinicie. Si vuelve a fallar después de reiniciar kit01, retrasa el arranque unos 2 minutos y hay que revisar las condiciones de espera que genera netplan.

## Si algo falla

- **Una VM no arrancó.** `virsh -c qemu:///system start <vm>` y revisar `virsh dominfo <vm>` (debe decir `Autostart: enable`).
- **Un servicio falló.** `journalctl -b -u <servicio>` muestra por qué en este arranque.

## Evidencia

La salida del script, con la hora de arranque de cada VM antes y después, el tiempo hasta que vuelven las sondas de cada familia y el estado completo después, y la matriz de flujos. En la sustentación, además, la captura de **Estado del kit** en verde.
