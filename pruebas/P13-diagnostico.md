# P13 - Diagnóstico

## Qué se prueba

**Enunciado.** Al simular una falla, los estudiantes usan logs y comandos para localizarla y explicar el impacto.
**Presentación.** Una falla inducida aparece en Grafana y en los logs.

Prometheus en kit01 sondea cada servicio en IPv4 e IPv6 (blackbox) y el estado de las unidades críticas (node_exporter). Grafana lo muestra en **Estado del kit**, en verde o rojo. Los logs de todos los equipos llegan a `/var/log/kitsalud/` en kit01.

## Qué necesitas

SSH a kit01 por NetBird y Grafana (`https://monitoreo.salud.movil` por NetBird, con `laura.gomez` o `admin`). Se hace en remoto.

## Paso a paso (falla 1, DNS caído)

1. Abrir **Estado del kit** en Grafana; todo en verde.
2. Inducir la falla en kit01 con `sudo systemctl stop named`.
3. Esperar 1 minuto y ver qué se pone en rojo.
4. Localizar la causa con los comandos de abajo, como si no se supiera qué pasó.
5. Explicar el impacto.
6. Restaurar con `sudo systemctl start named` y ver que todo vuelve a verde.

**Falla 2 (opcional), PostgreSQL caído.** En clinica01, `docker stop dhis2-db-1`. Se ponen en rojo DHIS2 y la sonda TCP del 5432, y los formularios no guardan. Restaurar con `docker start dhis2-db-1`.

## Con el script

Se ejecuta en la máquina de control (Ansible del kit, por NetBird), desde `docs/pruebas/`.

```bash
./scripts/P13-diagnostico.sh [dns|postgres]
```

Muestra las alertas de antes, induce la falla (pide confirmación), espera 75 s, junta las alertas nuevas, el síntoma, la causa (`systemctl`, `journalctl`, `ss` o `docker`) y el log central, restaura y comprueba que las alertas se apagan. Mientras corre, abrir **Estado del kit** para la captura. Cada línea sale como `[ OK ]` o `[FALLA]` y todo queda en `salidas/P13-<fecha>.txt`, que sirve de evidencia. Los comandos de abajo son los que usa el script, para ejecutarlos a mano o explicarlos.

## Comandos de diagnóstico

| Comando | Qué muestra | Con DNS caído |
|---|---|---|
| Grafana, **Estado del kit** | Qué sondas fallan y desde cuándo | Las sondas DNS en rojo (IPv4 e IPv6) |
| `curl -s http://127.0.0.1:9090/api/v1/alerts \| python3 -m json.tool \| grep -E "alertname\|servicio"` | Las alertas activas de Prometheus | `ServicioCaido` de DNS y `UnidadFallida` o la unidad `named` inactiva |
| `dig @10.20.20.10 pacientes.salud.movil` | Probar el síntoma | `connection refused` |
| `systemctl status named` | El estado del servicio | `inactive (dead)` con la hora en que se detuvo |
| `journalctl -u named --since -10min` | Qué pasó y quién lo detuvo | `Stopping named.service` |
| `sudo ss -lunp \| grep :53` | Si algo escucha en el 53 | Nada |
| `tail /var/log/kitsalud/kit01/dns.log` | El log central del DNS | Las últimas líneas antes de detenerse |
| `grep -i dns /var/log/kitsalud/clinica01/syslog.log \| tail` | El impacto en las VMs | Fallos de resolución, si los hay |

**Impacto de un DNS caído.** Los clientes no resuelven nombres del kit ni externos; los servicios siguen arriba pero solo se llega por IP; Samba AD sigue resolviendo su subzona para sí mismo; el login de Grafana por LDAPS falla si no resuelve `dc01.ad.salud.movil` y queda la cuenta local `admin`. Es un servicio de criticidad 1 (10.2).

**macOS.** Igual que P11, con Ansible y `sshpass` instalados.

## Si algo falla

- **Grafana no muestra el rojo.** Las sondas son cada 15 s y la alerta se dispara a los 30 s; esperar 1 minuto y recargar.

## Evidencia

Captura de **Estado del kit** con la falla y después de restaurar; salida de `systemctl status named`, `journalctl -u named` y la alerta de Prometheus; dos o tres frases con la causa, el impacto y cómo se restauró.
