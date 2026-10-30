# P12 - Reinicio

## Qué se prueba

**Enunciado.** Se reinicia un equipo y los servicios críticos se activan sin intervención manual.
**Presentación.** kit01 se reinicia y todo vuelve solo.

kit01 es el router, el firewall y el hipervisor. Al arrancar levantan solos nftables, la red, Kea, radvd, BIND9, Chrony, nginx, el portal, Prometheus, Grafana, rsyslog y NetBird; libvirt arranca las VMs con `autostart`, y Docker los contenedores con `restart: unless-stopped`. El reinicio también activa el kernel 6.8.0-146.

## Qué necesitas

**Alguien en el sitio** por si kit01 no vuelve (D-23). Se hace una sola vez y al final de la visita.

## Paso a paso

1. Anotar el estado antes (comandos de abajo) y la hora.
2. Reiniciar kit01 desde remoto: `ssh kitsalud@100.90.225.113 sudo reboot`.
3. Esperar 3-5 minutos. sw01 y el AP siguen encendidos.
4. Cuando NetBird responda (`ping 100.90.225.113`), revisar el estado después.
5. En el sitio, conectar un celular a la Comunidad. El portal vuelve a salir, porque las autorizaciones no sobreviven al reinicio, y después abren la biblioteca y los videos.
6. Si en 10 minutos no responde, en el sitio revisar la luz de kit01; mantener el botón 5 s, soltar y encender.

## Con el script

Se ejecuta en la máquina de control (Ansible del kit, por NetBird), con alguien en el sitio, desde `docs/pruebas/`.

```bash
./scripts/P12-reinicio.sh estado
./scripts/P12-reinicio.sh reiniciar
```

`estado` revisa unidades fallidas (por nombre), los servicios críticos de kit01, las VMs, los contenedores y Samba AD. `reiniciar` hace lo mismo, reinicia kit01 (pide confirmación), mide cuánto tarda en volver y revisa otra vez. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P12-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de verificación

| Dónde | Comando | Qué muestra | Esperado después |
|---|---|---|---|
| kit01 | `uptime` y `uname -r` | Que reinició y con qué kernel | Minutos encendido; `6.8.0-146-generic` |
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

**Antes del reinicio (2026-10-30).** `systemd-networkd-wait-online.service` está fallida desde el arranque del 9 de octubre: al arrancar se acabó el tiempo de espera de las interfaces. Las interfaces están bien (`networkctl list`, todas `configured`). Si vuelve a fallar después de P12, retrasa el arranque unos 2 minutos y hay que revisar las condiciones de espera que genera netplan.

## Si algo falla

- **Una VM no arrancó.** `virsh -c qemu:///system start <vm>` y revisar `virsh dominfo <vm>` (debe decir `Autostart: enable`).
- **Un servicio falló.** `journalctl -b -u <servicio>` muestra por qué en este arranque.

## Evidencia

Salida de `uptime`, `uname -r`, `systemctl --failed`, `virsh list` y `docker ps` antes y después, con la hora; captura de **Estado del kit** en verde; el tiempo que tardó en volver.
